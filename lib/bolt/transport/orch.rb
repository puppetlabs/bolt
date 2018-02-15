require 'base64'
require 'concurrent'
require 'json'
require 'orchestrator_client'
require 'bolt/transport/base'
require 'bolt/result'

module Bolt
  module Transport
    class Orch < Base
      CONF_FILE = File.expand_path('~/.puppetlabs/client-tools/orchestrator.conf')
      BOLT_MOCK_FILE = 'bolt/tasks/init'.freeze

      def initialize(config)
        super

        client_keys = %i[service-url token-file cacert]
        @client_opts = config.select { |k, _v| client_keys.include?(k) }
      end

      def create_client
        OrchestratorClient.new(@client_opts, true)
      end

      def build_request(targets, task, arguments)
        { task: task_name_from_path(task),
          environment: targets.first.options[:orch_task_environment],
          noop: arguments['_noop'],
          params: arguments.reject { |k, _| k == '_noop' },
          scope: {
            nodes: targets.map(&:host)
          } }
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

      def batch_command(targets, command, _options = {}, &callback)
        results = run_task_job(targets,
                               BOLT_MOCK_FILE,
                               action: 'command',
                               command: command,
                               &callback)
        callback ||= proc {}
        results.map! { |result| unwrap_bolt_result(result.target, result) }
        results.each do |result|
          callback.call(type: :node_result, result: result)
        end
      end

      def batch_script(targets, script, arguments, _options = {}, &callback)
        content = File.open(script, &:read)
        content = Base64.encode64(content)
        params = {
          action: 'script',
          content: content,
          arguments: arguments
        }
        callback ||= proc {}
        results = run_task_job(targets, BOLT_MOCK_FILE, params, &callback)
        results.map! { |result| unwrap_bolt_result(result.target, result) }
        results.each do |result|
          callback.call(type: :node_result, result: result)
        end
      end

      def batch_upload(targets, source, destination, _options = {}, &callback)
        content = File.open(source, &:read)
        content = Base64.encode64(content)
        mode = File.stat(source).mode
        params = {
          action: 'upload',
          path: destination,
          content: content,
          mode: mode
        }
        callback ||= proc {}
        results = run_task_job(targets, BOLT_MOCK_FILE, params, &callback)
        results.map! do |result|
          if result.error_hash
            result
          else
            Bolt::Result.for_upload(result.target, source, destination)
          end
        end
        results.each do |result|
          callback.call(type: :node_result, result: result) if callback
        end
      end

      def batches(targets)
        targets.group_by { |target| target.options[:orch_task_environment] }.values
      end

      def run_task_job(targets, task, arguments)
        body = build_request(targets, task, arguments)

        targets.each do |target|
          yield(type: :node_start, target: target) if block_given?
        end

        begin
          results = create_client.run_task(body)

          process_run_results(targets, results)
        rescue StandardError => e
          targets.map do |target|
            Bolt::Result.from_exception(target, e)
          end
        end
      end

      def batch_task(targets, task, _inputmethod, arguments, _options = {}, &callback)
        callback ||= proc {}
        results = run_task_job(targets, task, arguments, &callback)
        results.each do |result|
          callback.call(type: :node_result, result: result)
        end
      end

      # This avoids a refactor to pass more task data around
      def task_name_from_path(path)
        path = File.absolute_path(path)
        parts = path.split(File::Separator)
        if parts.length < 3 || parts[-2] != 'tasks'
          raise ArgumentError, "Task path was not inside a module."
        end
        mod = parts[-3]
        name = File.basename(path).split('.')[0]
        if name == 'init'
          mod
        else
          "#{mod}::#{name}"
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
