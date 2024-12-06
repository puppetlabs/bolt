# frozen_string_literal: true

require 'benchmark'

require_relative '../bolt/plan_creator'
require_relative '../bolt/util'

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

      targets = inventory.get_targets(targets, ext_glob: true)

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
        apply_prep_results = pal.in_plan_compiler(executor, inventory, plugins.puppetdb_client) do |compiler|
          compiler.call_function('apply_prep', targets, '_catch_errors' => true)
        end

        apply_results = pal.with_bolt_executor(executor, inventory, plugins.puppetdb_client) do
          Puppet.lookup(:apply_executor)
                .apply_ast(ast, apply_prep_results.ok_set.targets, catch_errors: true, noop: noop)
        end

        Bolt::ResultSet.new(apply_prep_results.error_set.results + apply_results.results)
      end
    end

    # Run a command on a list of targets.
    #
    # @param command [String] The command.
    # @param targets [Array[String]] The targets to run on.
    # @param env_vars [Hash] Environment variables to set on the target.
    # @return [Bolt::ResultSet]
    #
    def run_command(command, targets, env_vars: nil)
      targets = inventory.get_targets(targets, ext_glob: true)

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
    def download_file(source, destination, targets)
      destination = File.expand_path(destination, Dir.pwd)
      targets     = inventory.get_targets(targets, ext_glob: true)

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
    def upload_file(source, destination, targets)
      source  = find_file(source)
      targets = inventory.get_targets(targets, ext_glob: true)

      Bolt::Util.validate_file('source file', source, true)

      with_benchmark do
        executor.upload_file(targets, source, destination)
      end
    end

    # Show groups in the inventory.
    #
    # @return [Hash]
    #
    def list_groups
      {
        count: inventory.group_names.count,
        groups: inventory.group_names.sort,
        inventory: {
          default: config.default_inventoryfile.to_s,
          source: inventory.source
        }
      }
    end

    # Show available guides.
    #
    # @param guides [Hash] A map of topics to paths to guides.
    # @param outputter [Bolt::Outputter] An outputter instance.
    # @return [Boolean]
    #
    def list_guides
      { topics: load_guides.keys }
    end

    # Show a guide.
    #
    # @param topic [String] The topic to show.
    # @param guides [Hash] A map of topics to paths to guides.
    # @param outputter [Bolt::Outputter] An outputter instance.
    # @return [Boolean]
    #
    def show_guide(topic)
      if (path = load_guides[topic])
        analytics.event('Guide', 'known_topic', label: topic)

        begin
          guide = Bolt::Util.read_yaml_hash(path, 'guide')
        rescue SystemCallError => e
          raise Bolt::FileError("#{e.message}: unable to load guide page", filepath)
        end

        # Make sure both topic and guide keys are defined
        unless (%w[topic guide] - guide.keys).empty?
          msg = "Guide file #{path} must have a 'topic' key and 'guide' key, but has #{guide.keys} keys."
          raise Bolt::Error.new(msg, 'bolt/invalid-guide')
        end

        Bolt::Util.symbolize_top_level_keys(guide)
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
    def show_inventory(targets = nil)
      targets = group_targets_by_source(targets || ['all'])

      {
        adhoc: {
          count:   targets[:adhoc].count,
          targets: targets[:adhoc].map(&:detail)
        },
        inventory: {
          count:   targets[:inventory].count,
          targets: targets[:inventory].map(&:detail),
          file:    (inventory.source || config.default_inventoryfile).to_s,
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
        pal.lookup(key,
                   inventory.get_targets(targets, ext_glob: true),
                   inventory,
                   executor,
                   plan_vars: vars)
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
    def add_module(name, outputter)
      assert_project_file(config.project)

      installer = Bolt::ModuleInstaller.new(outputter, pal)

      installer.add(name,
                    config.project.modules,
                    config.project.puppetfile,
                    config.project.managed_moduledir,
                    config.project.project_file,
                    @plugins.resolve_references(config.module_install))
    end

    # Generate Puppet data types from project modules.
    #
    # @return [Boolean]
    #
    def generate_types
      pal.generate_types(cache: true)
    end

    # Install the project's modules.
    #
    # @param outputter [Bolt::Outputter] An outputter instance.
    # @param force [Boolean] Forcibly install modules.
    # @param resolve [Boolean] Resolve module dependencies.
    # @return [Boolean]
    #
    def install_modules(outputter, force: false, resolve: true)
      assert_project_file(config.project)

      if config.project.modules.empty? && resolve
        outputter.print_message(
          "Project configuration file #{config.project.project_file} does not "\
          "specify any module dependencies. Nothing to do."
        )
        return true
      end

      installer = Bolt::ModuleInstaller.new(outputter, pal)

      # GAVIN
      installer.install(config.project.modules,
                        config.project.puppetfile,
                        config.project.managed_moduledir,
                        @plugins.resolve_references(config.module_install),
                        force: force,
                        resolve: resolve)
    end

    # Show modules available to the project.
    #
    # @return [Hash] A map of module directories to module definitions.
    #
    def list_modules
      pal.list_modules
    end

    # Show module information.
    #
    # @param name [String] The name of the module.
    # @return [Hash] The module information.
    #
    def show_module(name)
      pal.show_module(name)
    end

    # Convert a YAML plan to a Puppet language plan.
    #
    # @param plan [String] The plan to convert. Can be a plan name or a path.
    # @return [String] The converted plan.
    #
    def convert_plan(plan)
      pal.convert_plan(plan)
    end

    # Create a new project-level plan.
    #
    # @param name [String] The name of the new plan.
    # @param puppet [Boolean] Create a Puppet language plan.
    # @param plan_script [String] Reference to the script to run in the new plan.
    # @return [Boolean]
    #
    def new_plan(name, puppet: false, plan_script: nil)
      Bolt::PlanCreator.validate_plan_name(config.project, name)

      if plan_script
        Bolt::Util.validate_file('script', find_file(plan_script))
      end

      Bolt::PlanCreator.create_plan(config.project.plans_path,
                                    name,
                                    is_puppet: puppet,
                                    script: plan_script)
    end

    # Run a plan.
    #
    # @param plan [String] The plan to run.
    # @param targets [Array[String], NilClass] The targets to pass to the plan.
    # @param params [Hash] Parameters to pass to the plan.
    # @return [Bolt::PlanResult]
    #
    def run_plan(plan, targets, params: {})
      plan_params = pal.get_plan_info(plan)['parameters']
      if targets && targets.any?
        if params['nodes'] || params['targets']
          key = params.include?('nodes') ? 'nodes' : 'targets'
          raise Bolt::CLIError,
                "A plan's '#{key}' parameter can be specified using the --#{key} option, but in that " \
                "case it must not be specified as a separate #{key}=<value> parameter nor included " \
                "in the JSON data passed in the --params option"
        end

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
      end

      sensitive_params = params.keys.select { |param| plan_params.dig(param, 'sensitive') }

      plan_context = { plan_name: plan, params: params, sensitive: sensitive_params }

      executor.start_plan(plan_context)
      result = pal.run_plan(plan, params, executor, inventory, plugins.puppetdb_client)
      executor.finish_plan(result)

      result
    rescue Bolt::Error => e
      Bolt::PlanResult.new(e, 'failure')
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
    def list_plugins
      { plugins: plugins.list_plugins, modulepath: pal.user_modulepath }
    end

    # Applies one or more policies to the specified targets.
    #
    # @param policies [String] A comma-separated list of policies to apply.
    # @param targets [Array[String]] The list of targets to apply the policies to.
    # @param noop [Boolean] Whether to apply the policies in no-operation mode.
    # @return [Bolt::ResultSet]
    #
    def apply_policies(policies, targets, noop: false)
      policies = policies.split(',')

      # Validate that the policies are available to the project.
      unavailable_policies = policies.reject do |policy|
        @config.policies&.any? do |known_policy|
          File.fnmatch?(known_policy, policy, File::FNM_EXTGLOB)
        end
      end

      if unavailable_policies.any?
        command = Bolt::Util.powershell? ? 'Get-BoltPolicy' : 'bolt policy show'

        # CODEREVIEW: Phrasing
        raise Bolt::Error.new(
          "The following policies are not available to the project: '#{unavailable_policies.join("', '")}'. "\
          "You must list policies in a project's 'policies' setting before Bolt can apply them to targets. "\
          "For a list of policies available to the project, run '#{command}'.",
          'bolt/unavailable-policy-error'
        )
      end

      # Validate that the policies are loadable Puppet classes.
      unloadable_policies = []

      @pal.in_catalog_compiler do |_|
        environment = Puppet.lookup(:current_environment)

        unloadable_policies = policies.reject do |policy|
          environment.known_resource_types.find_hostclass(policy)
        end
      end

      # CODEREVIEW: Phrasing
      if unloadable_policies.any?
        raise Bolt::Error.new(
          "The following policies cannot be loaded: '#{unloadable_policies.join("', '")}'. "\
          "Policies must be a Puppet class saved to a project's or module's manifests directory.",
          'bolt/unloadable-policy-error'
        )
      end

      # Execute a single include statement with all the policies to apply them
      # to the targets. Yay, reusable code!
      apply(nil, targets, code: "include #{policies.join(', ')}", noop: noop)
    end

    # Add a new policy to the project.
    #
    # @param name [String] The name of the new policy.
    # @return [Hash]
    #
    def new_policy(name)
      # Validate the policy name
      unless name =~ Bolt::Module::CONTENT_NAME_REGEX
        message = <<~MESSAGE.chomp
          Invalid policy name '#{name}'. Policy names are composed of one or more name segments
          separated by double colons '::'.

          Each name segment must begin with a lowercase letter, and can only include lowercase
          letters, digits, and underscores.

          Examples of valid policy names:
              - #{@config.project.name}
              - #{@config.project.name}::my_policy
        MESSAGE

        raise Bolt::ValidationError, message
      end

      # Validate that we're not running with the default project
      if @config.project.name.nil?
        command = Bolt::Util.powershell? ? 'New-BoltProject -Name <NAME>' : 'bolt project init <NAME>'
        message = <<~MESSAGE.chomp
          Can't create a policy for the default Bolt project because it doesn't
          have a name. Run '#{command}' to create a new project.
        MESSAGE
        raise Bolt::ValidationError, message
      end

      prefix, *name_segments, basename = name.split('::')

      # Error if name is not namespaced to project
      unless prefix == @config.project.name
        raise Bolt::ValidationError,
              "Policy name '#{name}' must begin with project name '#{@config.project.name}'. Did "\
              "you mean '#{@config.project.name}::#{name}'?"
      end

      # If the policy name is just the project name, use the special init.pp class
      basename ||= 'init'

      # Policies can be saved in subdirectories in the 'manifests/' directory
      policy_dir = File.expand_path(File.join(name_segments), @config.project.manifests)
      policy     = File.expand_path("#{basename}.pp", policy_dir)

      # Ensure the policy does not already exist
      if File.exist?(policy)
        raise Bolt::Error.new(
          "A policy with the name '#{name}' already exists at '#{policy}', nothing to do.",
          'bolt/existing-policy-error'
        )
      end

      # Create the policy directory structure in the current project
      begin
        FileUtils.mkdir_p(policy_dir)
      rescue Errno::EEXIST => e
        raise Bolt::Error.new(
          "#{e.message}; unable to create manifests directory '#{policy_dir}'",
          'bolt/existing-file-error'
        )
      end

      # Create the new policy
      begin
        File.write(policy, <<~POLICY)
          class #{name} {

          }
        POLICY
      rescue Errno::EACCES => e
        raise Bolt::FileError.new("#{e.message}; unable to create policy", policy)
      end

      # Update the project configuration to include the new policy
      project_config = Bolt::Util.read_yaml_hash(@config.project.project_file, 'project config')

      # Add the 'policies' key if it does not exist and de-dupiclate entries
      project_config['policies'] ||= []
      project_config['policies'] <<  name
      project_config['policies'].uniq!

      begin
        File.write(@config.project.project_file, project_config.to_yaml)
      rescue Errno::EACCES => e
        raise Bolt::FileError.new(
          "#{e.message}; unable to update project configuration",
          @config.project.project_file
        )
      end

      { name: name, path: policy }
    end

    # List policies available to the project.
    #
    # @return [Hash]
    #
    def list_policies
      unless @config.policies
        command = Bolt::Util.powershell? ? 'New-BoltPolicy -Name <NAME>' : 'bolt policy new <NAME>'

        raise Bolt::Error.new(
          "Project configuration file #{@config.project.project_file} does not "\
          "specify any policies. You can add policies to the project by including "\
          "a 'policies' key or creating a new policy using the '#{command}' "\
          "command.",
          'bolt/no-policies-error'
        )
      end

      { policies: @config.policies.uniq, modulepath: pal.user_modulepath }
    end

    # Initialize the current directory as a Bolt project.
    #
    # @param name [String] The name of the project.
    # @param [Bolt::Outputter] An outputter instance.
    # @param modules [Array[String], NilClass] Modules to install.
    # @return [Boolean]
    #
    def create_project(name, outputter, modules: nil)
      Bolt::ProjectManager.new(config, outputter, pal)
                          .create(Dir.pwd, name, modules)
    end

    # Migrate a project to current best practices.
    #
    # @param [Bolt::Outputter] An outputter instance.
    # @return [Boolean]
    #
    def migrate_project(outputter)
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
    def run_script(script, targets, arguments: [], env_vars: nil)
      script = find_file(script)

      Bolt::Util.validate_file('script', script)

      with_benchmark do
        executor.run_script(inventory.get_targets(targets, ext_glob: true),
                            script,
                            arguments,
                            env_vars: env_vars)
      end
    end

    # Generate a keypair using the configured secret plugin.
    #
    # @param force [Boolean] Forcibly create a keypair.
    # @param plugin [String] The secret plugin to use.
    # @return [Boolean]
    #
    def create_secret_keys(force: false, plugin: 'pkcs7')
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
    def decrypt_secret(ciphertext, plugin: 'pkcs7')
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
    def encrypt_secret(plaintext, plugin: 'pkcs7')
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
    def run_task(task, targets, params: {})
      targets = inventory.get_targets(targets, ext_glob: true)

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
    #
    private def find_file(path)
      return path if File.exist?(path) || Pathname.new(path).absolute?
      modulepath = Bolt::Config::Modulepath.new(config.modulepath)
      modules    = Bolt::Module.discover(modulepath.full_modulepath, config.project)
      mod, file  = path.split(File::SEPARATOR, 2)

      if modules[mod]
        logger.debug("Did not find file at #{File.expand_path(path)}, checking in module '#{mod}'")
        found = Bolt::Util.find_file_in_module(modules[mod].path, file || "")
        path  = found.nil? ? File.join(modules[mod].path, 'files', file) : found
      end

      path
    end

    # Get a list of Bolt guides.
    #
    private def load_guides
      root_path = File.expand_path(File.join(__dir__, '..', '..', 'guides'))
      files     = Dir.children(root_path).sort

      files.each_with_object({}) do |file, guides|
        next if file !~ /\.(yaml|yml)\z/
        topic = File.basename(file, ".*")
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
      targets     = inventory.get_targets(targets, ext_glob: true)

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
