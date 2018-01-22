require 'base64'
require 'json'
require 'orchestrator_client'

module Bolt
  class Orch < Node
    CONF_FILE = File.expand_path('~/.puppetlabs/client-tools/orchestrator.conf')
    BOLT_MOCK_FILE = 'bolt/tasks/init'.freeze

    def connect; end

    def disconnect; end

    def protocol
      'pcp'
    end

    def make_client
      opts = {}
      opts["service-url"] = @service_url if @service_url
      opts["token-file"] = @token_file if @token_file
      opts["cacert"] = @cacert if @cacert
      OrchestratorClient.new(opts, true)
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
               environment: @orch_task_environment,
               noop: arguments['_noop'],
               params: arguments.reject { |k, _| k == '_noop' },
               scope: {
                 nodes: [@target.host]
               } }
      # Should we handle errors here or let them propagate?
      results = client.run_task(body)
      node_result = results[0]
      state = node_result['state']
      result = node_result['result']

      # If it's finished or already has a proper error simply pass it to the
      # the result otherwise make sure an error is generated
      if state == 'finished' || result['_error']
        Bolt::Result.new(@target, value: result)
      elsif state == 'skipped'
        Bolt::Result.new(
          @target,
          value: { '_error' => {
            'kind' => 'puppetlabs.tasks/skipped-node',
            'msg' => "Node #{@target.host} was skipped",
            'details' => {}
          } }
        )
      else
        # Make a generic error with a unkown exit_code
        Bolt::Result.for_task(@target, result.to_json, '', 'unknown')
      end
    end

    # run_task generates a result that makes sense for a generic task which
    # needs to be unwrapped to extract stdout/stderr/exitcode.
    #
    def unwrap_bolt_result(result)
      if result.error_hash
        # something went wrong return the failure
        return result
      end

      Bolt::Result.for_command(@target, result.value['stdout'], result.value['stderr'], result.value['exit_code'])
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
      result = _run_task(BOLT_MOCK_FILE, 'stdin', params)
      result = Bolt::Result.new(@target) unless result.error_hash
      result
    end

    def _run_script(script, arguments)
      content = File.open(script, &:read)
      content = Base64.encode64(content)
      params = {
        action: 'script',
        content: content,
        arguments: arguments
      }
      unwrap_bolt_result(_run_task(BOLT_MOCK_FILE, 'stdin', params))
    end
  end
end
