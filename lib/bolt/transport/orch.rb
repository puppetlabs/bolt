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

      def initialize(config, executor = Concurrent.global_immediate_executor)
        super

        client_keys = %i[service-url token-file cacert]
        client_opts = config.select { |k, _v| client_keys.include?(k) }
        @client = Concurrent::Delay.new { OrchestratorClient.new(client_opts, true) }
        @client_lock = Mutex.new
      end

      def client
        if @client.value.nil?
          raise @client.reason
        else
          @client.value
        end
      end

      def upload(target, source, destination, _options = {})
        content = File.open(source, &:read)
        content = Base64.encode64(content)
        mode = File.stat(source).mode
        params = {
          action: 'upload',
          path: destination,
          content: content,
          mode: mode
        }
        result = run_task(target, BOLT_MOCK_FILE, 'stdin', params)
        result = Bolt::Result.for_upload(target, source, destination) unless result.error_hash
        result
      end

      def run_command(target, command, _options = {})
        result = run_task(target,
                          BOLT_MOCK_FILE,
                          'stdin',
                          action: 'command',
                          command: command,
                          options: {})
        unwrap_bolt_result(target, result)
      end

      def run_script(target, script, arguments, _options = {})
        content = File.open(script, &:read)
        content = Base64.encode64(content)
        params = {
          action: 'script',
          content: content,
          arguments: arguments
        }
        unwrap_bolt_result(target, run_task(target, BOLT_MOCK_FILE, 'stdin', params))
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
        targets_by_name = Hash[targets.map(&:name).zip(targets)]
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

      def batch_command(targets, command, _options = {})
        promises = batch_task(targets,
                              BOLT_MOCK_FILE,
                              'stdin',
                              action: 'command',
                              command: command,
                              options: {})
        promises.map { |promise| promise.then { |result| unwrap_bolt_result(result.target, result) } }
      end

      def batch_script(targets, script, arguments, _options = {})
        content = File.open(script, &:read)
        content = Base64.encode64(content)
        params = {
          action: 'script',
          content: content,
          arguments: arguments
        }
        promises = batch_task(targets, BOLT_MOCK_FILE, 'stdin', params)
        promises.map { |promise| promise.then { |result| unwrap_bolt_result(result.target, result) } }
      end

      def batch_upload(targets, source, destination, _options = {})
        content = File.open(source, &:read)
        content = Base64.encode64(content)
        mode = File.stat(source).mode
        params = {
          action: 'upload',
          path: destination,
          content: content,
          mode: mode
        }
        promises = batch_task(targets, BOLT_MOCK_FILE, 'stdin', params)
        promises.map do |promise|
          promise.then do |result|
            result.error_hash ? result : Bolt::Result.for_upload(result.target, source, destination)
          end
        end
      end

      def batch_task(targets, task, _inputmethod, arguments, _options = {})
        callback = block_given? ? Proc.new : proc {}
        targets.group_by { |target| target.options[:orch_task_environment] }.flat_map do |_environment, env_targets|
          body = build_request(env_targets, task, arguments)

          # Make promises to hold the eventual results. The `set` operation is
          # fast, so they can just execute in the thread that's creating them,
          # using the :immediate executor.
          result_ivars = Hash[env_targets.map { |target| [target, Concurrent::Promise.new(executor: :immediate)] }]

          @executor.post do
            env_targets.each do |target|
              callback.call(type: :node_start, target: target)
            end

            # The orchestrator client isn't thread-safe, so we have to do this
            # serially for now
            results = @client_lock.synchronize do
              client.run_task(body)
            end

            process_run_results(env_targets, results).each do |result|
              callback.call(type: :node_result, result: result)
              result_ivars[result.target].set(result)
            end
          end

          result_ivars.values
        end
      end

      def run_task(target, task, _inputmethod, arguments, _options = {})
        # batch_task([target], task, _inputmethod, arguments, _options = {})
        body = build_request([target], task, arguments)

        results = client.run_task(body)

        process_run_results([target], results).first
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
