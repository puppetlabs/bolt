# frozen_string_literal: true

require 'jsonclient'

module PlanExecutor
  class OrchClient
    attr_reader :plan_job, :http

    BOLT_COMMAND_TASK = Struct.new(:name).new('bolt_shim::command').freeze
    BOLT_SCRIPT_TASK = Struct.new(:name).new('bolt_shim::script').freeze
    BOLT_UPLOAD_TASK = Struct.new(:name).new('bolt_shim::upload').freeze

    def initialize(plan_job, http_client, logger)
      @plan_job = plan_job
      @logger = logger
      @http = http_client
      @environment = 'production'
    end

    def finish_plan(plan_result)
      body = {
        plan_job: @plan_job,
        result: plan_result.value || '',
        status: plan_result.status
      }
      post_command('internal/plan_finish', body)
    rescue StandardError => e
      @logger.error("Failed to finish plan #{plan_job}: #{e.message}")
    end

    def run_task_job(targets, task, arguments, options)
      # unpack any Sensitive data
      arguments = unwrap_sensitive_args(arguments)
      results = send_request(targets, task, arguments, options)

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

    def get(url)
      response = @http.get(url)
      if response.status != 200
        raise Bolt::Error.new(response.body['msg'], response.body['kind'], response.body['details'])
      end
      response.body
    end

    def post_command(url, body)
      response = @http.post(url, body)
      if response.status != 202
        raise Bolt::Error.new(response.body['msg'], response.body['kind'], response.body['details'])
      end
      response.body
    end

    def send_request(targets, task, arguments, options = {})
      description = options['_description']
      body = { task: task.name,
               environment: @environment,
               noop: arguments['_noop'],
               params: arguments.reject { |k, _| k.start_with?('_') },
               scope: {
                 nodes: targets.map(&:host)
               } }
      body[:description] = description if description
      body[:plan_job] = @plan_job if @plan_job

      url = post_command('internal/plan_task', body).dig('job', 'id')

      job = get(url)
      until %w[stopped finished failed].include?(job['state'])
        sleep 1
        job = get(url)
      end

      get(job.dig('nodes', 'id'))['items']
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

    def run_task(targets, task, arguments, options = {})
      run_task_job(targets, task, arguments, options)
    end

    def run_command(targets, command, options = {})
      params = { 'command' => command }
      run_task_job(targets, BOLT_COMMAND_TASK, params, options)
    end

    def run_script(targets, script, arguments, options = {})
      content = File.open(script, &:read)
      content = Base64.encode64(content)
      params = {
        'content' => content,
        'arguments' => arguments,
        'name' => Pathname(script).basename.to_s
      }
      callback ||= proc {}
      results = run_task_job(targets, BOLT_SCRIPT_TASK, params, options, &callback)
      results.map! { |result| unwrap_bolt_result(result.target, result) }
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

    def file_upload(targets, source, destination, options = {})
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
      results = run_task_job(targets, BOLT_UPLOAD_TASK, params, options)
      results.map! do |result|
        if result.error_hash
          result
        else
          Bolt::Result.for_upload(result.target, source, destination)
        end
      end
    end

    # Unwraps any Sensitive data in an arguments Hash, so the plain-text is passed
    # to the Task/Script.
    #
    # This works on deeply nested data structures composed of Hashes, Arrays, and
    # and plain-old data types (int, string, etc).
    def unwrap_sensitive_args(arguments)
      # Skip this if Puppet isn't loaded
      return arguments unless defined?(Puppet::Pops::Types::PSensitiveType::Sensitive)

      case arguments
      when Array
        # iterate over the array, unwrapping all elements
        arguments.map { |x| unwrap_sensitive_args(x) }
      when Hash
        # iterate over the arguments hash and unwrap all keys and values
        arguments.each_with_object({}) { |(k, v), h|
          h[unwrap_sensitive_args(k)] = unwrap_sensitive_args(v)
        }
      when Puppet::Pops::Types::PSensitiveType::Sensitive
        # this value is Sensitive, unwrap it
        unwrap_sensitive_args(arguments.unwrap)
      else
        # unknown data type, just return it
        arguments
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

    def connected?(targets)
      response = @http.post('inventory', nodes: targets.map(&:host))
      response.body['items'].all? { |node| node['connected'] }
    end
  end
end
