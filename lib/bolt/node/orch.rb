require 'base64'
require 'json'
require 'orchestrator_client'

module Bolt
  class Orch < Node
    CONF_FILE = File.expand_path('~/.puppetlabs/client-tools/orchestrator.conf')
    BOLT_MOCK_FILE = 'bolt/tasks/init'.freeze

    def connect; end

    def disconnect; end

    def make_client
      OrchestratorClient.new({}, true)
    end

    def client
      @client ||= make_client
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

    def _run_task(task, _input_method, arguments)
      body = { task: task_name_from_path(task),
               params: arguments,
               scope: {
                 nodes: [@host]
               } }
      # Should we handle errors here or let them propagate?
      results = client.run_task(body)
      node_result = results[0]
      state = node_result['state']
      result = node_result['result']

      result_output = Bolt::Node::ResultOutput.new
      result_output.stdout << result.to_json
      if state == 'finished'
        Bolt::Node::Success.new(result.to_json, result_output)
      else
        # Try to extract the exit_code from _error
        begin
          exit_code = result['_error']['details']['exit_code'] || 'unknown'
        rescue NoMethodError
          exit_code = 'unknown'
        end
        Bolt::Node::Failure.new(exit_code, result_output)
      end
    end

    # run_task generates a result that makes sense for a generic task which
    # needs to be unwrapped to extract stdout/stderr/exitcode.
    #
    def unwrap_bolt_result(result)
      task_result = JSON.parse(result.output.stdout.string)
      if task_result['exit_code'].nil?
        # something went wrong return the failure
        return result
      end

      # Otherwise create a new result with the captured output
      result_output = Bolt::Node::ResultOutput.new
      result_output.stdout << task_result['stdout']
      result_output.stderr << task_result['stderr']
      if (task_result['exit_code']).zero?
        Bolt::Node::Success.new(task_result['stdout'], result_output)
      else
        Bolt::Node::Failure.new(task_result['exit_code'], result_output)
      end
    end

    def _run_command(command, options = {})
      result = _run_task(BOLT_MOCK_FILE,
                         'stdin',
                         action: 'command',
                         command: command,
                         options: options)
      unwrap_bolt_result(result)
    end

    def _upload(source, destination)
      content = File.open(source, &:read)
      content = Base64.encode64(content)
      mode = File.stat(source).mode
      params = {
        action: 'upload',
        path: destination,
        content: content,
        mode: mode
      }
      _run_task(BOLT_MOCK_FILE, 'stdin', params)
    end

    def _run_script(script, _)
      content = File.open(script, &:read)
      content = Base64.encode64(content)
      params = {
        action: 'script',
        content: content
      }
      unwrap_bolt_result(_run_task(BOLT_MOCK_FILE, 'stdin', params))
    end
  end
end
