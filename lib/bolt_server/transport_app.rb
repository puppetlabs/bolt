# frozen_string_literal: true

require 'sinatra'
require 'addressable/uri'
require 'bolt'
require 'bolt/error'
require 'bolt/inventory'
require 'bolt/project'
require 'bolt/target'
require 'bolt_server/file_cache'
require 'bolt_server/plugin'
require 'bolt_server/plugin/puppet_connect_data'
require 'bolt_server/request_error'
require 'bolt/task/puppet_server'
require 'json'
require 'json-schema'

# These are only needed for the `/plans` endpoint.
require 'puppet'

# Needed by the `/project_file_metadatas` endpoint
require 'puppet/file_serving/fileset'

# Needed by the 'project_facts_plugin_tarball' endpoint
require 'minitar'
require 'zlib'

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
      connect-data
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
      @schemas = Hash[REQUEST_SCHEMAS.map do |basename|
        [basename, JSON.parse(File.read(File.join(__dir__, ['schemas', "#{basename}.json"])))]
      end]

      PARTIAL_SCHEMAS.each do |basename|
        schema_content = JSON.parse(File.read(File.join(__dir__, ['schemas', 'partials', "#{basename}.json"])))
        shared_schema = JSON::Schema.new(schema_content, Addressable::URI.parse("partial:#{basename}"))
        JSON::Validator.add_schema(shared_schema)
      end

      @executor = Bolt::Executor.new(0)

      @file_cache = BoltServer::FileCache.new(@config).setup

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

    def run_task(target, body)
      validate_schema(@schemas["action-run_task"], body)

      task_data = body['task']
      task = Bolt::Task::PuppetServer.new(task_data['name'], task_data['metadata'], task_data['files'], @file_cache)
      parameters = body['parameters'] || {}
      # Wrap parameters marked with '"sensitive": true' in the task metadata with a
      # Sensitive wrapper type. This way it's not shown in logs.
      if (param_spec = task.parameters)
        parameters.each do |k, v|
          if param_spec[k] && param_spec[k]['sensitive']
            parameters[k] = Puppet::Pops::Types::PSensitiveType::Sensitive.new(v)
          end
        end
      end

      @executor.run_task(target, task, parameters).each do |result|
        value = result.value
        next unless value.is_a?(Hash)
        next unless value.key?('_sensitive')
        value['_sensitive'] = value['_sensitive'].unwrap
      end
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
          dir = setting == :codedir ? codedir : dir
          cli << "--#{setting}" << dir
        end
        cli << "--environmentpath" << environmentpath
        cli << "--basemodulepath" << basemodulepath
        Puppet.settings.send(:clear_everything_for_tests)
        Puppet.initialize_settings(cli)
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

    def config_from_project(versioned_project)
      project_dir = File.join(@config['projects-dir'], versioned_project)
      unless Dir.exist?(project_dir)
        raise BoltServer::RequestError,
              "versioned_project: '#{project_dir}' does not exist"
      end
      project = Bolt::Project.create_project(project_dir)
      Bolt::Config.from_project(project, { log: { 'bolt-debug.log' => 'disable' } })
    end

    def pal_from_project_bolt_config(bolt_config)
      modulepath_object = Bolt::Config::Modulepath.new(
        bolt_config.modulepath,
        boltlib_path: [PE_BOLTLIB_PATH, Bolt::Config::Modulepath::BOLTLIB_PATH],
        builtin_content_path: @config['builtin-content-dir']
      )
      Bolt::PAL.new(modulepath_object, nil, nil, nil, nil, nil, bolt_config.project)
    end

    def in_bolt_project(versioned_project)
      @pal_mutex.synchronize do
        bolt_config = config_from_project(versioned_project)
        pal = pal_from_project_bolt_config(bolt_config)
        context = {
          pal: pal,
          config: bolt_config
        }
        yield context
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

    def file_metadatas(versioned_project, module_name, file)
      abs_file_path = @pal_mutex.synchronize do
        bolt_config = config_from_project(versioned_project)
        pal = pal_from_project_bolt_config(bolt_config)
        pal.in_bolt_compiler do
          mod = Puppet.lookup(:current_environment).module(module_name)
          raise BoltServer::RequestError, "module_name: '#{module_name}' does not exist" unless mod
          mod.file(file)
        end
      end

      unless abs_file_path
        raise BoltServer::RequestError,
              "file: '#{file}' does not exist inside the module's 'files' directory"
      end

      fileset = Puppet::FileServing::Fileset.new(abs_file_path, 'recurse' => 'yes')
      Puppet::FileServing::Fileset.merge(fileset).collect do |relative_file_path, base_path|
        metadata = Puppet::FileServing::Metadata.new(base_path, relative_path: relative_file_path)
        metadata.checksum_type = 'sha256'
        metadata.links = 'follow'
        metadata.collect
        metadata.to_data_hash
      end
    end

    # The provided block takes a module object and returns the list
    # of directories to search through. This is similar to
    # Bolt::Applicator.build_plugin_tarball.
    def build_project_plugins_tarball(versioned_project, &block)
      start_time = Time.now

      # Fetch the plugin files
      plugin_files = in_bolt_project(versioned_project) do |context|
        files = {}

        # Bolt also sets plugin_modulepath to user modulepath so do it here too for
        # consistency
        plugin_modulepath = context[:pal].user_modulepath
        Puppet.lookup(:current_environment).override_with(modulepath: plugin_modulepath).modules.each do |mod|
          search_dirs = block.call(mod)

          files[mod] ||= []
          Find.find(*search_dirs).each do |file|
            files[mod] << file if File.file?(file)
          end
        end

        files
      end

      # Pack the plugin files
      sio = StringIO.new
      begin
        output = Minitar::Output.new(Zlib::GzipWriter.new(sio))

        plugin_files.each do |mod, files|
          tar_dir = Pathname.new(mod.name)
          mod_dir = Pathname.new(mod.path)

          files.each do |file|
            tar_path = tar_dir + Pathname.new(file).relative_path_from(mod_dir)
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
        end

        duration = Time.now - start_time
        @logger.trace("Packed plugins in #{duration * 1000} ms")
      ensure
        output.close
      end

      Base64.encode64(sio.string)
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

    # Fetches the metadata for a single plan
    #
    # @param versioned_project [String] the project to fetch the plan from
    get '/project_plans/:module_name/:plan_name' do
      raise BoltServer::RequestError, "'versioned_project' is a required argument" if params['versioned_project'].nil?
      in_bolt_project(params['versioned_project']) do |context|
        plan_info = pe_plan_info(context[:pal], params[:module_name], params[:plan_name])
        plan_info = allowed_helper(context[:pal], plan_info, context[:config].project.plans)
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

    # Fetches the metadata for a single task
    #
    # @param bolt_versioned_project [String] the reference to the bolt-project directory to load task metadata from
    get '/project_tasks/:module_name/:task_name' do
      raise BoltServer::RequestError, "'versioned_project' is a required argument" if params['versioned_project'].nil?
      in_bolt_project(params['versioned_project']) do |context|
        ps_parameters = {
          'versioned_project' => params['versioned_project']
        }
        task_info = pe_task_info(context[:pal], params[:module_name], params[:task_name], ps_parameters)
        task_info = allowed_helper(context[:pal], task_info, context[:config].project.tasks)
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

    # Fetches the list of plans for a project
    #
    # @param versioned_project [String] the project to fetch the list of plans from
    get '/project_plans' do
      raise BoltServer::RequestError, "'versioned_project' is a required argument" if params['versioned_project'].nil?
      in_bolt_project(params['versioned_project']) do |context|
        plans_response = plan_list(context[:pal])

        # Dig in context for the allowlist of plans from project object
        plans_response.map! { |metadata| allowed_helper(context[:pal], metadata, context[:config].project.plans) }

        # We structure this array of plans to be an array of hashes so that it matches the structure
        # returned by the puppetserver API that serves data like this. Structuring the output this way
        # makes switching between puppetserver and bolt-server easier, which makes changes to switch
        # to bolt-server smaller/simpler.
        [200, plans_response.to_json]
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

    # Fetches the list of tasks for a bolt-project
    #
    # @param versioned_project [String] the project to fetch the list of tasks from
    get '/project_tasks' do
      raise BoltServer::RequestError, "'versioned_project' is a required argument" if params['versioned_project'].nil?
      in_bolt_project(params['versioned_project']) do |context|
        tasks_response = task_list(context[:pal])

        # Dig in context for the allowlist of tasks from project object
        tasks_response.map! { |metadata| allowed_helper(context[:pal], metadata, context[:config].project.tasks) }

        # We structure this array of tasks to be an array of hashes so that it matches the structure
        # returned by the puppetserver API that serves data like this. Structuring the output this way
        # makes switching between puppetserver and bolt-server easier, which makes changes to switch
        # to bolt-server smaller/simpler.
        [200, tasks_response.to_json]
      end
    end

    # Implements puppetserver's file_metadatas endpoint for projects.
    #
    # @param versioned_project [String] the versioned_project to fetch the file metadatas from
    get '/project_file_metadatas/:module_name/*' do
      raise BoltServer::RequestError, "'versioned_project' is a required argument" if params['versioned_project'].nil?
      file = params[:splat].first
      metadatas = file_metadatas(params['versioned_project'], params[:module_name], file)
      [200, metadatas.to_json]
    rescue ArgumentError => e
      [500, e.message]
    end

    # Returns a list of targets parsed from a Project inventory
    #
    # @param versioned_project [String] the versioned_project to compute the inventory from
    post '/project_inventory_targets' do
      content_type :json
      body = JSON.parse(request.body.read)
      validate_schema(@schemas["connect-data"], body)
      in_bolt_project(body['versioned_project']) do |context|
        if context[:config].inventoryfile &&
           context[:config].project.inventory_file.to_s !=
           context[:config].inventoryfile
          raise Bolt::ValidationError, "Project inventory must be defined in the " \
            "inventory.yaml file at the root of the project directory"
        end

        Bolt::Util.validate_file('inventory file', context[:config].project.inventory_file)

        begin
          # Set the default puppet_library plugin hook if it has not already been
          # set
          context[:config].data['plugin-hooks']['puppet_library'] ||= {
            'plugin'     => 'task',
            'task'       => 'puppet_agent::install',
            'parameters' => {
              'stop_service' => true
            }
          }

          connect_plugin = BoltServer::Plugin::PuppetConnectData.new(body['puppet_connect_data'])
          plugins = Bolt::Plugin.setup(context[:config], context[:pal], load_plugins: false)
          plugins.add_plugin(connect_plugin)
          %w[aws_inventory azure_inventory gcloud_inventory].each do |plugin_name|
            plugins.add_module_plugin(plugin_name) if plugins.known_plugin?(plugin_name)
          end
          inventory = Bolt::Inventory.from_config(context[:config], plugins)
          target_list = inventory.get_targets('all').map do |targ|
            targ.to_h.merge({ 'transport' => targ.transport, 'plugin_hooks' => targ.plugin_hooks })
          end
        rescue Bolt::Plugin::PluginError::LoadingDisabled => e
          msg = "Cannot load plugin #{e.details['plugin_name']}: plugin not supported"
          raise BoltServer::Plugin::PluginNotSupported.new(msg, e.details['plugin_name'])
        end

        [200, target_list.to_json]
      end
    end

    # Returns the base64 encoded tar archive of plugin code that is needed to calculate
    # custom facts
    #
    # @param versioned_project [String] the versioned_project to build the plugin tarball from
    get '/project_facts_plugin_tarball' do
      raise BoltServer::RequestError, "'versioned_project' is a required argument" if params['versioned_project'].nil?
      content_type :json

      plugins_tarball = build_project_plugins_tarball(params['versioned_project']) do |mod|
        search_dirs = []
        search_dirs << mod.plugins if mod.plugins?
        search_dirs << mod.pluginfacts if mod.pluginfacts?
        search_dirs
      end

      [200, plugins_tarball.to_json]
    end

    # Returns the base64 encoded tar archive of _all_ plugin code for a project
    #
    # @param versioned_project [String] the versioned_project to build the plugin tarball from
    get '/project_plugin_tarball' do
      raise BoltServer::RequestError, "'versioned_project' is a required argument" if params['versioned_project'].nil?
      content_type :json

      plugins_tarball = build_project_plugins_tarball(params['versioned_project']) do |mod|
        search_dirs = []
        search_dirs << mod.plugins if mod.plugins?
        search_dirs << mod.pluginfacts if mod.pluginfacts?
        search_dirs << mod.files if mod.files?
        type_files = "#{mod.path}/types"
        search_dirs << type_files if File.exist?(type_files)
        search_dirs
      end

      [200, plugins_tarball.to_json]
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
