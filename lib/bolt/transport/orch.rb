# frozen_string_literal: true

require 'base64'
require 'find'
require 'json'
require 'pathname'
require_relative '../../bolt/transport/base'
require_relative 'orch/connection'

module Bolt
  module Transport
    class Orch < Base
      BOLT_COMMAND_TASK = Struct.new(:name).new('bolt_shim::command').freeze
      BOLT_SCRIPT_TASK = Struct.new(:name).new('bolt_shim::script').freeze
      BOLT_UPLOAD_TASK = Struct.new(:name).new('bolt_shim::upload').freeze

      attr_writer :plan_context

      def provided_features
        ['puppet-agent']
      end

      def initialize(*args)
        # lazy-load expensive gem code
        require 'orchestrator_client'

        @connections = {}
        super
      end

      def finish_plan(result)
        if result.is_a? Bolt::PlanResult
          @connections.each_value do |conn|
            conn.finish_plan(result)
          rescue StandardError => e
            @logger.trace("Failed to finish plan on #{conn.key}: #{e.message}")
          end
        end
      end

      # It's safe to create connections here for now because the
      # batches/threads are per connection.
      def get_connection(conn_opts)
        key = Connection.get_key(conn_opts)
        unless (conn = @connections[key])
          conn = @connections[key] = Connection.new(conn_opts, @plan_context, logger)
        end
        conn
      end

      def process_run_results(targets, results, task_name, position = [])
        targets_by_name = Hash[targets.map { |t| t.host || t.name }.zip(targets)]
        results.map do |node_result|
          target = targets_by_name[node_result['name']]
          state = node_result['state']
          result = node_result['result']

          # If it's finished or already has a proper error simply pass it to the
          # the result otherwise make sure an error is generated
          if state == 'finished' || (result && result['_error'])
            if result['_error']
              unless result['_error'].is_a?(Hash)
                result['_error'] = { 'kind' => 'puppetlabs.tasks/task-error',
                                     'issue_code' => 'TASK_ERROR',
                                     'msg' => result['_error'],
                                     'details' => {} }
              end

              result['_error']['details'] ||= {}
              unless result['_error']['details'].is_a?(Hash)
                deets = result['_error']['details']
                result['_error']['details'] = { 'msg' => deets }
              end
              file_line = %w[file line].zip(position).to_h.compact
              result['_error']['details'].merge!(file_line) unless result['_error']['details']['file']
            end

            Bolt::Result.new(target, value: result, action: 'task', object: task_name)
          elsif state == 'skipped'
            details = %w[file line].zip(position).to_h.compact
            Bolt::Result.new(
              target,
              value: { '_error' => {
                'kind' => 'puppetlabs.tasks/skipped-node',
                'msg' => "Target #{target.safe_name} was skipped",
                'details' => details
              } },
              action: 'task', object: task_name
            )
          else
            # Make a generic error with a unkown exit_code
            Bolt::Result.for_task(target, result.to_json, '', 'unknown', task_name, position)
          end
        end
      end

      def batch_command(targets, command, options = {}, position = [], &callback)
        if options[:env_vars] && !options[:env_vars].empty?
          raise NotImplementedError, "pcp transport does not support setting environment variables"
        end

        params = {
          'command' => command
        }
        results = run_task_job(targets,
                               BOLT_COMMAND_TASK,
                               params,
                               options,
                               position,
                               &callback)
        callback ||= proc {}
        results.map! { |result| unwrap_bolt_result(result.target, result, 'command', command) }
        results.each do |result|
          callback.call(type: :node_result, result: result)
        end
      end

      def batch_script(targets, script, arguments, options = {}, position = [], &callback)
        if options[:env_vars] && !options[:env_vars].empty?
          raise NotImplementedError, "pcp transport does not support setting environment variables"
        end

        content = File.open(script, &:read)
        content = Base64.encode64(content)
        params = {
          'content' => content,
          'arguments' => arguments,
          'name' => Pathname(script).basename.to_s
        }
        callback ||= proc {}
        results = run_task_job(targets, BOLT_SCRIPT_TASK, params, options, position, &callback)
        results.map! { |result| unwrap_bolt_result(result.target, result, 'script', script) }
        results.each do |result|
          callback.call(type: :node_result, result: result)
        end
      end

      def pack(directory)
        # lazy-load expensive gem code
        require 'minitar'
        require 'zlib'

        start_time = Time.now
        io = StringIO.new
        output = Minitar::Output.new(Zlib::GzipWriter.new(io))
        Find.find(directory) do |file|
          next unless File.file?(file)

          tar_path = Pathname.new(file).relative_path_from(Pathname.new(directory))
          @logger.trace("Packing #{file} to #{tar_path}")
          stat = File.stat(file)
          content = File.binread(file)
          output.tar.add_file_simple(
            tar_path.to_s,
            data: content,
            size: content.size,
            mode: stat.mode & 0o777,
            mtime: stat.mtime
          )
        end

        duration = Time.now - start_time
        @logger.trace("Packed upload in #{duration * 1000} ms")

        output.close
        io.string
      ensure
        # Closes both tar and sgz.
        output&.close
      end

      def batch_upload(targets, source, destination, options = {}, position = [], &callback)
        stat = File.stat(source)
        content = if stat.directory?
                    pack(source)
                  else
                    File.open(source, &:read)
                  end
        content = Base64.encode64(content)
        mode = File.stat(source).mode
        params = {
          'path' => destination,
          'content' => content,
          'mode' => mode,
          'directory' => stat.directory?
        }
        callback ||= proc {}
        results = run_task_job(targets, BOLT_UPLOAD_TASK, params, options, position, &callback)
        results.map! do |result|
          if result.error_hash
            result
          else
            Bolt::Result.for_upload(result.target, source, destination)
          end
        end
        results.each do |result|
          callback&.call(type: :node_result, result: result)
        end
      end

      def batch_download(targets, *_args)
        error = {
          'kind'    => 'bolt/not-supported-error',
          'msg'     => 'pcp transport does not support downloading files',
          'details' => {}
        }

        targets.map do |target|
          Bolt::Result.new(target, error: error, action: 'download')
        end
      end

      def batches(targets)
        targets.group_by { |target| Connection.get_key(target.options) }.values
      end

      def run_task_job(targets, task, arguments, options, position)
        targets.each do |target|
          yield(type: :node_start, target: target) if block_given?
        end

        begin
          # unpack any Sensitive data
          arguments = unwrap_sensitive_args(arguments)
          results = get_connection(targets.first.options).run_task(targets, task, arguments, options)

          process_run_results(targets, results, task.name, position)
        rescue OrchestratorClient::ApiError => e
          targets.map do |target|
            Bolt::Result.new(target, error: e.data)
          end
        rescue StandardError => e
          targets.map do |target|
            Bolt::Result.from_exception(target, e, action: 'task')
          end
        end
      end

      def batch_task(targets, task, arguments, options = {}, position = [], &callback)
        callback ||= proc {}
        results = run_task_job(targets, task, arguments, options, position, &callback)
        results.each do |result|
          callback.call(type: :node_result, result: result)
        end
      end

      def batch_task_with(_targets, _task, _target_mapping, _options = {}, _position = [])
        raise NotImplementedError, "pcp transport does not support run_task_with()"
      end

      def batch_connected?(targets)
        resp = get_connection(targets.first.options).query_inventory(targets)
        resp['items'].all? { |node| node['connected'] }
      end

      # run_task generates a result that makes sense for a generic task which
      # needs to be unwrapped to extract stdout/stderr/exitcode.
      #
      def unwrap_bolt_result(target, result, action, obj)
        if result.error_hash
          # something went wrong return the failure
          return result
        end

        # If we get here, there's no error so we don't need the file or line
        # number
        Bolt::Result.for_command(target, result.value, action, obj, [])
      end
    end
  end
end
