# frozen_string_literal: true

require 'base64'
require 'concurrent'
require 'json'
require 'orchestrator_client'
require 'bolt/transport/base'
require 'bolt/transport/orch/connection'
require 'bolt/result'

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
        %w[service-url cacert token-file task-environment local-validation]
      end

      PROVIDED_FEATURES = ['puppet-agent'].freeze

      def self.validate(options)
        validation_flag = options['local-validation']
        unless !!validation_flag == validation_flag
          raise Bolt::ValidationError, 'local-validation option must be a Boolean true or false'
        end
      end

      def initialize(*args)
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

      def process_run_results(targets, results)
        targets_by_name = Hash[targets.map(&:host).zip(targets)]
        results.map do |node_result|
          target = targets_by_name[node_result['name']]
          state = node_result['state']
          result = node_result['result']

          # If it's finished or already has a proper error simply pass it to the
          # the result otherwise make sure an error is generated
          if state == 'finished' || (result && result['_error'])
            Bolt::Result.new(target, value: result)
          elsif state == 'skipped'
            Bolt::Result.new(
              target,
              value: { '_error' => {
                'kind' => 'puppetlabs.tasks/skipped-node',
                'msg' => "Node #{target.host} was skipped",
                'details' => {}
              } }
            )
          else
            # Make a generic error with a unkown exit_code
            Bolt::Result.for_task(target, result.to_json, '', 'unknown')
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
        results.map! { |result| unwrap_bolt_result(result.target, result) }
        results.each do |result|
          callback.call(type: :node_result, result: result)
        end
      end

      def batch_script(targets, script, arguments, options = {}, &callback)
        content = File.open(script, &:read)
        content = Base64.encode64(content)
        params = {
          'content' => content,
          'arguments' => arguments
        }
        callback ||= proc {}
        results = run_task_job(targets, BOLT_SCRIPT_TASK, params, options, &callback)
        results.map! { |result| unwrap_bolt_result(result.target, result) }
        results.each do |result|
          callback.call(type: :node_result, result: result)
        end
      end

      def batch_upload(targets, source, destination, options = {}, &callback)
        content = File.open(source, &:read)
        content = Base64.encode64(content)
        mode = File.stat(source).mode
        params = {
          'path' => destination,
          'content' => content,
          'mode' => mode
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

          process_run_results(targets, results)
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

      # run_task generates a result that makes sense for a generic task which
      # needs to be unwrapped to extract stdout/stderr/exitcode.
      #
      def unwrap_bolt_result(target, result)
        if result.error_hash
          # something went wrong return the failure
          return result
        end

        Bolt::Result.for_command(target, result.value['stdout'], result.value['stderr'], result.value['exit_code'])
      end
    end
  end
end
