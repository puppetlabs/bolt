# frozen_string_literal: true

require 'base64'
require 'find'
require 'json'
require 'pathname'
require 'bolt/transport/base'
require 'bolt/transport/orch/connection'

module Bolt
  module Transport
    class Orch < Base
      CONF_FILE = if !ENV['HOME'].nil?
                    File.expand_path('~/.puppetlabs/client-tools/orchestrator.conf')
                  else
                    '/etc/puppetlabs/client-tools/orchestrator.conf'
                  end
      BOLT_COMMAND_TASK = Struct.new(:name).new('bolt_shim::command').freeze
      BOLT_SCRIPT_TASK = Struct.new(:name).new('bolt_shim::script').freeze
      BOLT_UPLOAD_TASK = Struct.new(:name).new('bolt_shim::upload').freeze

      attr_writer :plan_context

      def self.options
        %w[host service-url cacert token-file task-environment job-poll-interval job-poll-timeout]
      end

      def self.default_options
        { 'task-environment' => 'production' }
      end

      def provided_features
        ['puppet-agent']
      end

      def self.validate(options); end

      def initialize(*args)
        # lazy-load expensive gem code
        require 'orchestrator_client'

        @connections = {}
        super
      end

      def finish_plan(result)
        if result.is_a? Bolt::PlanResult
          @connections.each_value do |conn|
            begin
              conn.finish_plan(result)
            rescue StandardError => e
              @logger.debug("Failed to finish plan on #{conn.key}: #{e.message}")
            end
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

      def process_run_results(targets, results, task_name)
        targets_by_name = Hash[targets.map { |t| t.host || t.name }.zip(targets)]
        results.map do |node_result|
          target = targets_by_name[node_result['name']]
          state = node_result['state']
          result = node_result['result']

          # If it's finished or already has a proper error simply pass it to the
          # the result otherwise make sure an error is generated
          if state == 'finished' || (result && result['_error'])
            Bolt::Result.new(target, value: result, action: 'task', object: task_name)
          elsif state == 'skipped'
            Bolt::Result.new(
              target,
              value: { '_error' => {
                'kind' => 'puppetlabs.tasks/skipped-node',
                'msg' => "Node #{target.safe_name} was skipped",
                'details' => {}
              } },
              action: 'task', object: task_name
            )
          else
            # Make a generic error with a unkown exit_code
            Bolt::Result.for_task(target, result.to_json, '', 'unknown', task_name)
          end
        end
      end

      def batch_command(targets, command, options = {}, &callback)
        params = {
          'command' => command
        }
        results = run_task_job(targets,
                               BOLT_COMMAND_TASK,
                               params,
                               options,
                               &callback)
        callback ||= proc {}
        results.map! { |result| unwrap_bolt_result(result.target, result, 'command', command) }
        results.each do |result|
          callback.call(type: :node_result, result: result)
        end
      end

      def batch_script(targets, script, arguments, options = {}, &callback)
        content = File.open(script, &:read)
        content = Base64.encode64(content)
        params = {
          'content' => content,
          'arguments' => arguments,
          'name' => Pathname(script).basename.to_s
        }
        callback ||= proc {}
        results = run_task_job(targets, BOLT_SCRIPT_TASK, params, options, &callback)
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
          @logger.debug("Packing #{file} to #{tar_path}")
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
        @logger.debug("Packed upload in #{duration * 1000} ms")

        output.close
        io.string
      ensure
        # Closes both tar and sgz.
        output&.close
      end

      def batch_upload(targets, source, destination, options = {}, &callback)
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
        results = run_task_job(targets, BOLT_UPLOAD_TASK, params, options, &callback)
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

      def batches(targets)
        targets.group_by { |target| Connection.get_key(target.options) }.values
      end

      def run_task_job(targets, task, arguments, options)
        targets.each do |target|
          yield(type: :node_start, target: target) if block_given?
        end

        begin
          # unpack any Sensitive data
          arguments = unwrap_sensitive_args(arguments)
          results = get_connection(targets.first.options).run_task(targets, task, arguments, options)

          process_run_results(targets, results, task.name)
        rescue OrchestratorClient::ApiError => e
          targets.map do |target|
            Bolt::Result.new(target, error: e.data)
          end
        rescue StandardError => e
          targets.map do |target|
            Bolt::Result.from_exception(target, e)
          end
        end
      end

      def batch_task(targets, task, arguments, options = {}, &callback)
        callback ||= proc {}
        results = run_task_job(targets, task, arguments, options, &callback)
        results.each do |result|
          callback.call(type: :node_result, result: result)
        end
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

        Bolt::Result.for_command(target,
                                 result.value['stdout'],
                                 result.value['stderr'],
                                 result.value['exit_code'],
                                 action, obj)
      end
    end
  end
end
