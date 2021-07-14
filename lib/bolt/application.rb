# frozen_string_literal: true

require 'benchmark'

require 'bolt/util'

module Bolt
  class Application
    attr_reader :analytics, :config, :executor, :inventory, :logger, :pal, :plugins
    private     :analytics, :config, :executor, :inventory, :logger, :pal, :plugins

    def initialize(
      analytics:,
      config:,
      executor:,
      inventory:,
      pal:,
      plugins:
    )
      @analytics = analytics
      @config    = config
      @executor  = executor
      @inventory = inventory
      @logger    = Bolt::Logger.logger(self)
      @pal       = pal
      @plugins   = plugins
    end

    # Shuts down the application.
    #
    def shutdown
      executor.shutdown
    end

    # Apply Puppet manifest code to a list of targets.
    #
    # @param manifest [String, NilClass] The path to a Puppet manifest file.
    # @param targets [Array[String]] The targets to run on.
    # @param code [String] Puppet manifest code to apply.
    # @param noop [Boolean] Whether to apply in no-operation mode.
    # @return [Bolt::ResultSet]
    #
    def apply(manifest, targets, code: '', noop: false)
      manifest_code = if manifest
                        Bolt::Util.validate_file('manifest', manifest)
                        File.read(File.expand_path(manifest))
                      else
                        code
                      end

      targets = inventory.get_targets(targets)

      Puppet[:tasks] = false
      ast = pal.parse_manifest(manifest_code, manifest)

      if defined?(ast.body) &&
         (ast.body.is_a?(Puppet::Pops::Model::HostClassDefinition) ||
         ast.body.is_a?(Puppet::Pops::Model::ResourceTypeDefinition))
        message = "Manifest only contains definitions and will result in no changes on the targets. "\
                  "Definitions must be declared for their resources to be applied. You can read more "\
                  "about defining and declaring classes and types in the Puppet documentation at "\
                  "https://puppet.com/docs/puppet/latest/lang_classes.html and "\
                  "https://puppet.com/docs/puppet/latest/lang_defined_types.html"
        Bolt::Logger.warn("empty_manifest", message)
      end

      # Apply logging looks like plan logging
      executor.publish_event(type: :plan_start, plan: nil)

      with_benchmark do
        pal.in_plan_compiler(executor, inventory, plugins.puppetdb_client) do |compiler|
          compiler.call_function('apply_prep', targets)
        end

        pal.with_bolt_executor(executor, inventory, plugins.puppetdb_client) do
          Puppet.lookup(:apply_executor).apply_ast(ast, targets, catch_errors: true, noop: noop)
        end
      end
    end

    # Run a command on a list of targets.
    #
    # @param command [String] The command.
    # @param targets [Array[String]] The targets to run on.
    # @param env_vars [Hash] Environment variables to set on the target.
    # @return [Bolt::ResultSet]
    #
    def command_run(command, targets, env_vars: {})
      targets = inventory.get_targets(targets)

      with_benchmark do
        executor.run_command(targets, command, env_vars: env_vars)
      end
    end

    # Download a file from a list of targets to a directory on the controller.
    #
    # @param source [String] The path to the file on the targets.
    # @param destination [String] The path to the directory on the controller.
    # @param targets [Array[String]] The targets to run on.
    # @return [Bolt::ResultSet]
    #
    def file_download(source, destination, targets)
      destination = File.expand_path(destination, Dir.pwd)
      targets     = inventory.get_targets(targets)

      with_benchmark do
        executor.download_file(targets, source, destination)
      end
    end

    # Upload a file from the controller to a list of targets.
    #
    # @param source [String] The path to the file on the controller.
    # @param destination [String] The destination path on the targets.
    # @param targets [Array[String]] The targets to run on.
    # @return [Bolt::ResultSet]
    #
    def file_upload(source, destination, targets)
      future  = executor.future&.fetch('file_paths', false)
      source  = find_file(source, future)
      targets = inventory.get_targets(targets)

      Bolt::Util.validate_file('source file', source, true)

      with_benchmark do
        executor.upload_file(targets, source, destination)
      end
    end

    # Show groups in the inventory.
    #
    # @return [Hash]
    #
    def group_show
      {
        count: inventory.group_names.count,
        groups: inventory.group_names.sort,
        inventory: {
          default: config.default_inventoryfile.to_s,
          source: inventory.source
        }
      }
    end

    # Show Bolt guides.
    #
    # @param topic [String] The topic to show.
    # @return [Hash] A list of topics or the guide for the specified topic.
    #
    def guide(topic = nil)
      guides = load_guides

      if topic
        show_guide(topic, guides)
      else
        list_guides(guides)
      end
    end

    # Show available guides.
    #
    # @param guides [Hash] A map of topics to paths to guides.
    # @param outputter [Bolt::Outputter] An outputter instance.
    # @return [Boolean]
    #
    private def list_guides(guides)
      { topics: guides.keys - ['guide'] }
    end

    # Show a guide.
    #
    # @param topic [String] The topic to show.
    # @param guides [Hash] A map of topics to paths to guides.
    # @param outputter [Bolt::Outputter] An outputter instance.
    # @return [Boolean]
    #
    private def show_guide(topic, guides)
      if guides[topic]
        analytics.event('Guide', 'known_topic', label: topic)

        begin
          guide = File.read(guides[topic])
        rescue SystemCallError => e
          raise Bolt::FileError("#{e.message}: unable to load guide page", filepath)
        end

        { topic: topic, guide: guide }
      else
        analytics.event('Guide', 'unknown_topic', label: topic)
        raise Bolt::Error.new(
          "Unknown topic '#{topic}'. For a list of available topics, run 'bolt guide'.",
          'bolt/unknown-topic'
        )
      end
    end

    # Show inventory information.
    #
    # @param targets [Array[String]] The targets to show.
    # @return [Hash]
    #
    def inventory_show(targets = nil)
      targets = group_targets_by_source(targets || ['all'])

      {
        adhoc: {
          count: targets[:adhoc].count,
          targets: targets[:adhoc].map(&:detail)
        },
        inventory: {
          count: targets[:inventory].count,
          targets: targets[:inventory].map(&:detail),
          file: (inventory.source || config.default_inventoryfile).to_s,
          default: config.default_inventoryfile.to_s
        },
        targets: targets.values.flatten.map(&:detail),
        count: targets.values.flatten.count
      }
    end

    # Lookup a value with Hiera.
    #
    # @param key [String] The key to look up in the hierarchy.
    # @param targets [Array[String]] The targets to use as context.
    # @param vars [Hash] Variables to set in the scope.
    # @return [Bolt::ResultSet, String] The result of the lookup.
    #
    def lookup(key, targets, vars: {})
      executor.publish_event(type: :plan_start, plan: nil)

      with_benchmark do
        pal.lookup(
          key,
          inventory.get_targets(targets),
          inventory,
          executor,
          plan_vars: vars
        )
      end
    end

    # Lookup a value with Hiera using plan_hierarchy.
    #
    # @param key [String] The key to lookup up in the plan_hierarchy.
    # @param vars [Hash] Variables to set in the scope.
    # @return [String] The result of the lookup.
    #
    def plan_lookup(key, vars: {})
      pal.plan_hierarchy_lookup(key, plan_vars: vars)
    end

    # Add a new module to the project.
    #
    # @param name [String] The name of the module to add.
    # @param outputter [Bolt::Outputter] An outputter instance.
    # @return [Boolean]
    #
    def module_add(name, outputter)
      assert_project_file(config.project)

      installer = Bolt::ModuleInstaller.new(outputter, pal)

      installer.add(name,
                    config.project.modules,
                    config.project.puppetfile,
                    config.project.managed_moduledir,
                    config.project.project_file,
                    config.module_install)
    end

    # Generate Puppet data types from project modules.
    #
    # @return [Boolean]
    #
    def module_generate_types
      pal.generate_types(cache: true)
    end

    # Install the project's modules.
    #
    # @param outputter [Bolt::Outputter] An outputter instance.
    # @param force [Boolean] Forcibly install modules.
    # @param resolve [Boolean] Resolve module dependencies.
    # @return [Boolean]
    #
    def module_install(outputter, force: false, resolve: true)
      assert_project_file(config.project)

      if config.project.modules.empty? && resolve
        outputter.print_message(
          "Project configuration file #{config.project.project_file} does not "\
          "specify any module dependencies. Nothing to do."
        )
        return true
      end

      installer = Bolt::ModuleInstaller.new(outputter, pal)

      installer.install(config.project.modules,
                        config.project.puppetfile,
                        config.project.managed_moduledir,
                        config.module_install,
                        force: force,
                        resolve: resolve)
    end

    # Show modules available to the project.
    #
    # @return [Hash] A map of module directories to module definitions.
    #
    def module_show
      pal.list_modules
    end

    # Convert a YAML plan to a Puppet language plan.
    #
    # @param plan [String] The plan to convert. Can be a plan name or a path.
    # @return [String] The converted plan.
    #
    def plan_convert(plan)
      pal.convert_plan(plan)
    end

    # Create a new project-level plan.
    #
    # @param name [String] The name of the new plan.
    # @param puppet [Boolean] Create a Puppet language plan.
    # @return [Boolean]
    #
    def plan_new(name, puppet: false)
      Bolt::PlanCreator.validate_input(config.project, name)
      Bolt::PlanCreator.create_plan(config.project.plans_path, name, puppet)
    end

    # Run a plan.
    #
    # @param plan [String] The plan to run.
    # @param targets [Array[String], NilClass] The targets to pass to the plan.
    # @param params [Hash] Parameters to pass to the plan.
    # @return [Bolt::PlanResult]
    #
    def plan_run(plan, targets, params: {})
      if targets && targets.any?
        if params['nodes'] || params['targets']
          key = params.include?('nodes') ? 'nodes' : 'targets'
          raise Bolt::CLIError,
                "A plan's '#{key}' parameter can be specified using the --#{key} option, but in that " \
                "case it must not be specified as a separate #{key}=<value> parameter nor included " \
                "in the JSON data passed in the --params option"
        end

        plan_params  = pal.get_plan_info(plan)['parameters']
        target_param = plan_params.dig('targets', 'type') =~ /TargetSpec/
        node_param   = plan_params.include?('nodes')

        if node_param && target_param
          msg = "Plan parameters include both 'nodes' and 'targets' with type 'TargetSpec', " \
                "neither will populated with the value for --nodes or --targets."
          Bolt::Logger.warn("nodes_targets_parameters", msg)
        elsif node_param
          params['nodes'] = targets.join(',')
        elsif target_param
          params['targets'] = targets.join(',')
        end

        inventory.get_targets(targets)
      end

      plan_context = { plan_name: plan, params: params }

      executor.start_plan(plan_context)
      result = pal.run_plan(plan, params, executor, inventory, plugins.puppetdb_client)
      executor.finish_plan(result)

      result
    end

    # Show plan information.
    #
    # @param plan [String] The name of the plan to show.
    # @return [Hash]
    #
    def show_plan(plan)
      pal.get_plan_info(plan)
    end

    # List plans available to the project.
    #
    # @param filter [String] A substring to filter plans by.
    # @return [Hash]
    #
    def list_plans(filter: nil)
      {
        plans:      filter_content(pal.list_plans_with_cache(filter_content: true), filter),
        modulepath: pal.user_modulepath
      }
    end

    # Show available plugins.
    #
    # @return [Hash]
    #
    def plugin_show
      { plugins: plugins.list_plugins, modulepath: pal.user_modulepath }
    end

    # Initialize the current directory as a Bolt project.
    #
    # @param name [String] The name of the project.
    # @param [Bolt::Outputter] An outputter instance.
    # @param modules [Array[String], NilClass] Modules to install.
    # @return [Boolean]
    #
    def project_init(name, outputter, modules: nil)
      Bolt::ProjectManager.new(config, outputter, pal)
                          .create(Dir.pwd, name, modules)
    end

    # Migrate a project to current best practices.
    #
    # @param [Bolt::Outputter] An outputter instance.
    # @return [Boolean]
    #
    def project_migrate(outputter)
      Bolt::ProjectManager.new(config, outputter, pal).migrate
    end

    # Run a script on a list of targets.
    #
    # @param script [String] The path to the script to run.
    # @param targets [Array[String]] The targets to run on.
    # @param arguments [Array[String], NilClass] Arguments to pass to the script.
    # @param env_vars [Hash] Environment variables to set on the target.
    # @return [Bolt::ResultSet]
    #
    def script_run(script, targets, arguments: [], env_vars: {})
      future = executor.future&.fetch('file_paths', false)
      script = find_file(script, future)

      Bolt::Util.validate_file('script', script)

      with_benchmark do
        executor.run_script(inventory.get_targets(targets), script, arguments, env_vars: env_vars)
      end
    end

    # Generate a keypair using the configured secret plugin.
    #
    # @param force [Boolean] Forcibly create a keypair.
    # @param plugin [String] The secret plugin to use.
    # @return [Boolean]
    #
    def secret_createkeys(force: false, plugin: 'pkcs7')
      unless plugins.by_name(plugin)
        raise Bolt::Plugin::PluginError::Unknown, plugin
      end

      plugins.get_hook(plugin, :secret_createkeys)
             .call('force' => force)
    end

    # Decrypt ciphertext using the configured secret plugin.
    #
    # @param ciphertext [String] The ciphertext to decrypt.
    # @param plugin [String] The secret plugin to use.
    # @return [Boolean]
    #
    def secret_decrypt(ciphertext, plugin: 'pkcs7')
      unless plugins.by_name(plugin)
        raise Bolt::Plugin::PluginError::Unknown, plugin
      end

      plugins.get_hook(plugin, :secret_decrypt)
             .call('encrypted_value' => ciphertext)
    end

    # Encrypt plaintext using the configured secret plugin.
    #
    # @param plaintext [String] The plaintext to encrypt.
    # @param plugin [String] The secret plugin to use.
    # @return [Boolean]
    #
    def secret_encrypt(plaintext, plugin: 'pkcs7')
      unless plugins.by_name(plugin)
        raise Bolt::Plugin::PluginError::Unknown, plugin
      end

      plugins.get_hook(plugin, :secret_encrypt)
             .call('plaintext_value' => plaintext)
    end

    # Run a task on a list of targets.
    #
    # @param task [String] The name of the task.
    # @param options [Hash] Additional options.
    # @return [Bolt::ResultSet]
    #
    def task_run(task, targets, params: {})
      targets = inventory.get_targets(targets)

      with_benchmark do
        pal.run_task(task, targets, params, executor, inventory)
      end
    end

    # Show task information.
    #
    # @param task [String] The name of the task to show.
    # @return [Hash]
    #
    def show_task(task)
      { task: pal.get_task(task) }
    end

    # List available tasks.
    #
    # @param filter [String] A substring to filter tasks by.
    # @return [Hash]
    #
    def list_tasks(filter: nil)
      {
        tasks:      filter_content(pal.list_tasks_with_cache(filter_content: true), filter),
        modulepath: pal.user_modulepath
      }
    end

    # Assert that there is a project configuration file.
    #
    # @param project [Bolt::Project] The Bolt project.
    #
    private def assert_project_file(project)
      unless project.project_file?
        command = Bolt::Util.powershell? ? 'New-BoltProject' : 'bolt project init'

        msg = "Could not find project configuration file #{project.project_file}, unable "\
              "to install modules. To create a Bolt project, run '#{command}'."

        raise Bolt::Error.new(msg, 'bolt/missing-project-config-error')
      end
    end

    # Filter a list of content by matching substring.
    #
    # @param content [Hash] The content to filter.
    # @param filter [String] The substring to filter content by.
    #
    private def filter_content(content, filter)
      return content unless content && filter
      content.select { |name,| name.include?(filter) }
    end

    # Return the path to a file. If the path is an absolute or relative path to
    # a file, and the file exists, return the path as-is. Otherwise, check if
    # the path is a Puppet file path and look for the file in a module's files
    # directory.
    #
    # @param path [String] The path to the file.
    # @param future_file_paths [Boolean] Whether to use future file path behavior.
    #
    private def find_file(path, future_file_paths)
      return path if File.exist?(path) || Pathname.new(path).absolute?
      modulepath = Bolt::Config::Modulepath.new(config.modulepath)
      modules    = Bolt::Module.discover(modulepath.full_modulepath, config.project)
      mod, file = path.split(File::SEPARATOR, 2)

      if modules[mod]
        logger.debug("Did not find file at #{File.expand_path(path)}, checking in module '#{mod}'")
        found = Bolt::Util.find_file_in_module(modules[mod].path, file || "", future_file_paths)
        path = found.nil? ? File.join(modules[mod].path, 'files', file) : found
      end

      path
    end

    # Get a list of Bolt guides.
    #
    private def load_guides
      root_path = File.expand_path(File.join(__dir__, '..', '..', 'guides'))
      files     = Dir.children(root_path).sort

      files.each_with_object({}) do |file, guides|
        next if file !~ /\.txt\z/
        topic = File.basename(file, '.txt')
        guides[topic] = File.join(root_path, file)
      end
    rescue SystemCallError => e
      raise Bolt::FileError.new("#{e.message}: unable to load guides directory", root_path)
    end

    # Return a hash of targets sorted by those that are found in the inventory
    # and those that are provided on the command line.
    #
    # @param targets [Array[String]] The targets to group.
    #
    private def group_targets_by_source(targets)
      # Retrieve the known group and target names. This needs to be done before
      # updating targets, as that will add adhoc targets to the inventory.
      known_names = inventory.target_names
      targets     = inventory.get_targets(targets)

      inventory_targets, adhoc_targets = targets.partition do |target|
        known_names.include?(target.name)
      end

      { inventory: inventory_targets, adhoc: adhoc_targets }
    end

    # Benchmark the action and set the elapsed time on the result.
    #
    private def with_benchmark
      result = nil

      elapsed_time = Benchmark.realtime do
        result = yield
      end

      result.tap { |r| r.elapsed_time = elapsed_time if r.is_a?(Bolt::ResultSet) }
    end
  end
end
