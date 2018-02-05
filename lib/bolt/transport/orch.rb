require 'base64'
require 'json'
require 'orchestrator_client'

module Bolt
  module Transport
    class Orch
      CONF_FILE = File.expand_path('~/.puppetlabs/client-tools/orchestrator.conf')
      BOLT_MOCK_FILE = 'bolt/tasks/init'.freeze

      attr_reader :client, :logger

      def initialize(config)
        client_keys = %i[service-url token-file cacert]
        client_opts = config.select { |k, _v| client_keys.include?(k) }
        @client = OrchestratorClient.new(client_opts, true)
        @logger = Logging.logger[self]
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

      def run_task(target, task, _inputmethod, arguments, _options = {})
        body = { task: task_name_from_path(task),
                 environment: target.options[:orch_task_environment],
                 noop: arguments['_noop'],
                 params: arguments.reject { |k, _| k == '_noop' },
                 scope: {
                   nodes: [target.host]
                 } }
        results = client.run_task(body)
        node_result = results[0]
        state = node_result['state']
        result = node_result['result']

        # If it's finished or already has a proper error simply pass it to the
        # the result otherwise make sure an error is generated
        if state == 'finished' || result['_error']
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
