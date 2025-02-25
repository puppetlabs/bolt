# frozen_string_literal: true

require 'sinatra'
require 'addressable/uri'
require 'bolt'
require 'bolt/error'
require 'bolt/inventory'
require 'bolt/target'
require 'bolt_server/file_cache'
require 'bolt_server/request_error'
require 'bolt/task/puppet_server'
require 'json'
require 'json-schema'

# These are only needed for the `/plans` endpoint.
require 'puppet'

module BoltServer
  class TransportApp < Sinatra::Base
    # This disables Sinatra's error page generation
    set :show_exceptions, false

    # These partial schemas are reused to build multiple request schemas
    PARTIAL_SCHEMAS = %w[target-any target-ssh target-winrm task].freeze

    # These schemas combine shared schemas to describe client requests
    REQUEST_SCHEMAS = %w[
      action-check_node_connections
      action-run_command
      action-run_task
      action-run_script
      action-upload_file
      transport-ssh
      transport-winrm
    ].freeze

    # PE_BOLTLIB_PATH is intended to function exactly like the BOLTLIB_PATH used
    # in Bolt::PAL. Paths and variable names are similar to what exists in
    # Bolt::PAL, but with a 'PE' prefix.
    PE_BOLTLIB_PATH = '/opt/puppetlabs/server/apps/bolt-server/pe-bolt-modules'

    # For now at least, we maintain an entirely separate codedir from
    # puppetserver by default, so that filesync can work properly. If filesync
    # is not used, this can instead match the usual puppetserver codedir.
    # See the `orchestrator.bolt.codedir` tk config setting.
    DEFAULT_BOLT_CODEDIR = '/opt/puppetlabs/server/data/orchestration-services/code'

    def initialize(config)
      @config = config
      @schemas = REQUEST_SCHEMAS.map do |basename|
        [basename, JSON.parse(File.read(File.join(__dir__, ['schemas', "#{basename}.json"])))]
      end.to_h

      PARTIAL_SCHEMAS.each do |basename|
        schema_content = JSON.parse(File.read(File.join(__dir__, ['schemas', 'partials', "#{basename}.json"])))
        shared_schema = JSON::Schema.new(schema_content, Addressable::URI.parse("partial:#{basename}"))
        JSON::Validator.add_schema(shared_schema)
      end
      @file_cache = BoltServer::FileCache.new(@config).setup
      @executor = Bolt::Executor.new(0)

      # This is needed until the PAL is threadsafe.
      @pal_mutex = Mutex.new

      @logger = Bolt::Logger.logger(self)

      super(nil)
    end

    def scrub_stack_trace(result)
      if result.dig('value', '_error', 'details', 'stack_trace')
        result['value']['_error']['details'].reject! { |k| k == 'stack_trace' }
      end
      result
    end

    def validate_schema(schema, body)
      schema_error = JSON::Validator.fully_validate(schema, body)
      if schema_error.any?
        raise BoltServer::RequestError.new("There was an error validating the request body.",
                                           schema_error)
      end
    end

    # Turns a Bolt::ResultSet object into a status hash that is fit
    # to return to the client in a response. In the case of every action
    # *except* check_node_connections the response will be a single serialized Result.
    # In the check_node_connections case the response will be a hash with the top level "status"
    # of the result and the serialized individual target results.
    def result_set_to_data(result_set, aggregate: false)
      # use ResultSet#ok method to determine status of a (potentially) aggregate result before serializing
      result_set_status = result_set.ok ? 'success' : 'failure'
      scrubbed_results = result_set.map do |result|
        scrub_stack_trace(result.to_data)
      end

      if aggregate
        {
          status: result_set_status,
          result: scrubbed_results
        }
      else
        # If there was only one target, return the first result on its own
        scrubbed_results.first
      end
    end

    def unwrap_sensitive_results(result_set)
      # Take a ResultSet and unwrap sensitive values
      result_set.each do |result|
        value = result.value
        next unless value.is_a?(Hash)
        next unless value.key?('_sensitive')
        value['_sensitive'] = value['_sensitive'].unwrap
      end
    end

    def task_helper(target, task, parameters, timeout = nil)
      # Wrap parameters marked with '"sensitive": true' in the task metadata with a
      # Sensitive wrapper type. This way it's not shown in logs.
      if (param_spec = task.parameters)
        parameters.each do |k, v|
          if param_spec[k] && param_spec[k]['sensitive']
            parameters[k] = Puppet::Pops::Types::PSensitiveType::Sensitive.new(v)
          end
        end
      end

      if timeout && timeout > 0
        task_thread = Thread.new do
          unwrap_sensitive_results(@executor.run_task(target, task, parameters))
        end
        # Wait for the timeout for the task to execute in the thread. If `join` times out, result will be nil.
        if task_thread.join(timeout).nil?
          task_thread.kill
          raise Bolt::Error.new("Task execution on #{target.first.safe_name} timed out after #{timeout} seconds",
                                'boltserver/task-timeout')
        else
          task_thread.value
        end
      else
        unwrap_sensitive_results(@executor.run_task(target, task, parameters))
      end
    end

    def run_task(target, body)
      validate_schema(@schemas["action-run_task"], body)

      task_data = body['task']
      task = Bolt::Task::PuppetServer.new(task_data['name'], task_data['metadata'], task_data['files'], @file_cache)
      task_helper(target, task, body['parameters'] || {}, body['timeout'])
    end

    def run_command(target, body)
      validate_schema(@schemas["action-run_command"], body)
      command = body['command']
      @executor.run_command(target, command)
    end

    def check_node_connections(targets, body)
      validate_schema(@schemas["action-check_node_connections"], body)

      # Puppet Enterprise's orchestrator service uses the
      # check_node_connections endpoint to check whether nodes that should be
      # contacted over SSH or WinRM are responsive. The wait time here is 0
      # because the endpoint is meant to be used for a single check of all
      # nodes; External implementations of wait_until_available (like
      # orchestrator's) should contact the endpoint in their own loop.
      @executor.wait_until_available(targets, wait_time: 0)
    end

    def upload_file(target, body)
      validate_schema(@schemas["action-upload_file"], body)
      files = body['files']
      destination = body['destination']
      job_id = body['job_id']
      cache_dir = @file_cache.create_cache_dir(job_id.to_s)
      FileUtils.mkdir_p(cache_dir)
      files.each do |file|
        relative_path = file['relative_path']
        uri = file['uri']
        sha256 = file['sha256']
        kind = file['kind']
        path = File.join(cache_dir, relative_path)
        case kind
        when 'file'
          # The parent should already be created by `directory` entries,
          # but this is to be on the safe side.
          parent = File.dirname(path)
          FileUtils.mkdir_p(parent)
          @file_cache.serial_execute { @file_cache.download_file(path, sha256, uri) }
        when 'directory'
          # Create directory in cache so we can move files in.
          FileUtils.mkdir_p(path)
        else
          raise BoltServer::RequestError, "Invalid kind: '#{kind}' supplied. Must be 'file' or 'directory'."
        end
      end
      # We need to special case the scenario where only one file was
      # included in the request to download. Otherwise, the call to upload_file
      # will attempt to upload with a directory as a source and potentially a
      # filename as a destination on the host. In that case the end result will
      # be the file downloaded to a directory with the same name as the source
      # filename, rather than directly to the filename set in the destination.
      upload_source = if files.size == 1 && files[0]['kind'] == 'file'
                        File.join(cache_dir, files[0]['relative_path'])
                      else
                        cache_dir
                      end
      @executor.upload_file(target, upload_source, destination)
    end

    def run_script(target, body)
      validate_schema(@schemas["action-run_script"], body)
      # Download the file onto the machine.
      file_location = @file_cache.update_file(body['script'])
      @executor.run_script(target, file_location, body['arguments'])
    end

    # This function is nearly identical to Bolt::Pal's `with_puppet_settings` with the
    # one difference that we set the codedir to point to actual code, rather than the
    # tmpdir. We only use this funtion inside the Modulepath initializer so that Puppet
    # is correctly configured to pull environment configuration correctly. If we don't
    # set codedir in this way: when we try to load and interpolate the modulepath it
    # won't correctly load.
    #
    # WARNING: THIS FUNCTION SHOULD ONLY BE CALLED INSIDE A SYNCHRONIZED PAL MUTEX
    def with_pe_pal_init_settings(codedir, environmentpath, basemodulepath)
      Dir.mktmpdir('pe-bolt') do |dir|
        cli = []
        Puppet::Settings::REQUIRED_APP_SETTINGS.each do |setting|
          dir = codedir if setting == :codedir
          cli << "--#{setting}" << dir
        end
        cli << "--environmentpath" << environmentpath
        cli << "--basemodulepath" << basemodulepath
        Puppet.settings.send(:clear_everything_for_tests)
        Puppet.initialize_settings(cli)
        Puppet[:versioned_environment_dirs] = true
        yield
      end
    end

    # Use puppet to identify the modulepath from an environment.
    #
    # WARNING: THIS FUNCTION SHOULD ONLY BE CALLED INSIDE A SYNCHRONIZED PAL MUTEX
    def modulepath_from_environment(environment_name)
      codedir = @config['environments-codedir'] || DEFAULT_BOLT_CODEDIR
      environmentpath = @config['environmentpath'] || "#{codedir}/environments"
      basemodulepath = @config['basemodulepath'] || "#{codedir}/modules:/opt/puppetlabs/puppet/modules"
      with_pe_pal_init_settings(codedir, environmentpath, basemodulepath) do
        environment = Puppet.lookup(:environments).get!(environment_name)
        environment.modulepath
      end
    end

    def in_pe_pal_env(environment)
      raise BoltServer::RequestError, "'environment' is a required argument" if environment.nil?
      @pal_mutex.synchronize do
        modulepath_obj = Bolt::Config::Modulepath.new(
          modulepath_from_environment(environment),
          boltlib_path: [PE_BOLTLIB_PATH, Bolt::Config::Modulepath::BOLTLIB_PATH]
        )
        pal = Bolt::PAL.new(modulepath_obj, nil, nil)
        yield pal
      rescue Puppet::Environments::EnvironmentNotFound
        raise BoltServer::RequestError, "environment: '#{environment}' does not exist"
      end
    end

    def pe_plan_info(pal, module_name, plan_name)
      # Handle case where plan name is simply module name with special `init.pp` plan
      plan_name = if plan_name == 'init' || plan_name.nil?
                    module_name
                  else
                    "#{module_name}::#{plan_name}"
                  end
      plan_info = pal.get_plan_info(plan_name)
      # Path to module is meaningless in PE
      plan_info.delete('module')
      plan_info
    end

    def build_puppetserver_uri(file_identifier, module_name, parameters)
      segments = file_identifier.split('/', 3)
      if segments.size == 1
        {
          'path' => "/puppet/v3/file_content/tasks/#{module_name}/#{file_identifier}",
          'params' => parameters
        }
      else
        module_segment, mount_segment, name_segment = *segments
        {
          'path' => case mount_segment
                    when 'files'
                      "/puppet/v3/file_content/modules/#{module_segment}/#{name_segment}"
                    when 'scripts'
                      "/puppet/v3/file_content/scripts/#{module_segment}/#{name_segment}"
                    when 'tasks'
                      "/puppet/v3/file_content/tasks/#{module_segment}/#{name_segment}"
                    when 'lib'
                      "/puppet/v3/file_content/plugins/#{name_segment}"
                    end,
          'params' => parameters
        }
      end
    end

    def pe_task_info(pal, module_name, task_name, parameters)
      # Handle case where task name is simply module name with special `init` task
      task_name = if task_name == 'init' || task_name.nil?
                    module_name
                  else
                    "#{module_name}::#{task_name}"
                  end
      task = pal.get_task(task_name)
      files = task.files.map do |file_hash|
        {
          'filename' => file_hash['name'],
          'sha256' => Digest::SHA256.hexdigest(File.read(file_hash['path'])),
          'size_bytes' => File.size(file_hash['path']),
          'uri' => build_puppetserver_uri(file_hash['name'], module_name, parameters)
        }
      end
      {
        'metadata' => task.metadata,
        'name' => task.name,
        'files' => files
      }
    end

    def allowed_helper(pal, metadata, allowlist)
      allowed = !pal.filter_content([metadata['name']], allowlist).empty?
      metadata.merge({ 'allowed' => allowed })
    end

    def task_list(pal)
      tasks = pal.list_tasks
      tasks.map { |task_name, _description| { 'name' => task_name } }
    end

    def plan_list(pal)
      plans = pal.list_plans.flatten
      plans.map { |plan_name| { 'name' => plan_name } }
    end

    get '/' do
      200
    end

    if ENV['RACK_ENV'] == 'dev'
      get '/admin/gc' do
        GC.start
        200
      end
    end

    get '/admin/gc_stat' do
      [200, GC.stat.to_json]
    end

    get '/admin/status' do
      stats = Puma.stats
      [200, stats.is_a?(Hash) ? stats.to_json : stats]
    end

    get '/500_error' do
      raise 'Unexpected error'
    end

    ACTIONS = %w[
      check_node_connections
      run_command
      run_task
      run_script
      upload_file
      apply
      apply_prep
    ].freeze

    def make_ssh_target(target_hash)
      defaults = {
        'host-key-check' => false
      }

      overrides = {
        'load-config' => false
      }

      opts = defaults.merge(target_hash).merge(overrides)

      if opts['private-key-content']
        private_key_content = opts.delete('private-key-content')
        opts['private-key'] = { 'key-data' => private_key_content }
      end

      data = {
        'uri' => target_hash['hostname'],
        'config' => {
          'transport' => 'ssh',
          'ssh' => opts.slice(*Bolt::Config::Transport::SSH.options)
        }
      }

      inventory = Bolt::Inventory.empty
      Bolt::Target.from_hash(data, inventory)
    end

    post '/ssh/:action' do
      not_found unless ACTIONS.include?(params[:action])

      content_type :json
      body = JSON.parse(request.body.read)

      validate_schema(@schemas["transport-ssh"], body)

      targets = (body['targets'] || [body['target']]).map do |target|
        make_ssh_target(target)
      end

      result_set = method(params[:action]).call(targets, body)

      aggregate = params[:action] == 'check_node_connections'
      [200, result_set_to_data(result_set, aggregate: aggregate).to_json]
    end

    def make_winrm_target(target_hash)
      defaults = {
        'ssl' => false,
        'ssl-verify' => false
      }

      opts = defaults.merge(target_hash)

      data = {
        'uri' => target_hash['hostname'],
        'config' => {
          'transport' => 'winrm',
          'winrm' => opts.slice(*Bolt::Config::Transport::WinRM.options)
        }
      }

      inventory = Bolt::Inventory.empty
      Bolt::Target.from_hash(data, inventory)
    end

    post '/winrm/:action' do
      not_found unless ACTIONS.include?(params[:action])

      content_type :json
      body = JSON.parse(request.body.read)

      validate_schema(@schemas["transport-winrm"], body)

      targets = (body['targets'] || [body['target']]).map do |target|
        make_winrm_target(target)
      end

      result_set = method(params[:action]).call(targets, body)

      aggregate = params[:action] == 'check_node_connections'
      [200, result_set_to_data(result_set, aggregate: aggregate).to_json]
    end

    # Fetches the metadata for a single plan
    #
    # @param environment [String] the environment to fetch the plan from
    get '/plans/:module_name/:plan_name' do
      in_pe_pal_env(params['environment']) do |pal|
        plan_info = pe_plan_info(pal, params[:module_name], params[:plan_name])
        [200, plan_info.to_json]
      end
    end

    # Fetches the metadata for a single task
    #
    # @param environment [String] the environment to fetch the task from
    get '/tasks/:module_name/:task_name' do
      in_pe_pal_env(params['environment']) do |pal|
        ps_parameters = {
          'environment' => params['environment']
        }
        task_info = pe_task_info(pal, params[:module_name], params[:task_name], ps_parameters)
        [200, task_info.to_json]
      end
    end

    # Fetches the list of plans for an environment, optionally fetching all metadata for each plan
    #
    # @param environment [String] the environment to fetch the list of plans from
    # @param metadata [Boolean] Set to true to fetch all metadata for each plan. Defaults to false
    get '/plans' do
      in_pe_pal_env(params['environment']) do |pal|
        plans = pal.list_plans.flatten
        if params['metadata']
          plan_info = plans.each_with_object({}) do |full_name, acc|
            # Break apart module name from plan name
            module_name, plan_name = full_name.split('::', 2)
            acc[full_name] = pe_plan_info(pal, module_name, plan_name)
          end
          [200, plan_info.to_json]
        else
          # We structure this array of plans to be an array of hashes so that it matches the structure
          # returned by the puppetserver API that serves data like this. Structuring the output this way
          # makes switching between puppetserver and bolt-server easier, which makes changes to switch
          # to bolt-server smaller/simpler.
          [200, plans.map { |plan| { 'name' => plan } }.to_json]
        end
      end
    end

    # Fetches the list of tasks for an environment
    #
    # @param environment [String] the environment to fetch the list of tasks from
    get '/tasks' do
      in_pe_pal_env(params['environment']) do |pal|
        tasks_response = task_list(pal).to_json

        # We structure this array of tasks to be an array of hashes so that it matches the structure
        # returned by the puppetserver API that serves data like this. Structuring the output this way
        # makes switching between puppetserver and bolt-server easier, which makes changes to switch
        # to bolt-server smaller/simpler.
        [200, tasks_response]
      end
    end

    error 404 do
      err = Bolt::Error.new("Could not find route #{request.path}",
                            'boltserver/not-found')
      [404, err.to_json]
    end

    error BoltServer::RequestError do |err|
      [400, err.to_json]
    end

    error Bolt::Error do |err|
      # In order to match the request code pattern, unknown plan/task content should 400. This also
      # gives us an opportunity to trim the message instructing users to use CLI to show available content.
      if ['bolt/unknown-plan', 'bolt/unknown-task'].include?(err.kind)
        [404, BoltServer::RequestError.new(err.msg.split('.').first).to_json]
      else
        [500, err.to_json]
      end
    end

    error StandardError do
      e = env['sinatra.error']
      err = Bolt::Error.new("500: Unknown error: #{e.message}",
                            'boltserver/server-error')
      [500, err.to_json]
    end
  end
end
