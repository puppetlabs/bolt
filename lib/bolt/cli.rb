# frozen_string_literal: true

# Avoid requiring the CLI from other files. It has side-effects - such as loading r10k -
# that are undesirable when using Bolt as a library.

require 'uri'
require 'benchmark'
require 'json'
require 'io/console'
require 'logging'
require 'optparse'
require 'bolt/analytics'
require 'bolt/bolt_option_parser'
require 'bolt/config'
require 'bolt/error'
require 'bolt/executor'
require 'bolt/inventory'
require 'bolt/rerun'
require 'bolt/logger'
require 'bolt/outputter'
require 'bolt/puppetdb'
require 'bolt/plugin'
require 'bolt/pal'
require 'bolt/target'
require 'bolt/version'
require 'bolt/secret'

module Bolt
  class CLIExit < StandardError; end
  class CLI
    COMMANDS = { 'command' => %w[run],
                 'script' => %w[run],
                 'task' => %w[show run],
                 'plan' => %w[show run convert],
                 'file' => %w[upload],
                 'puppetfile' => %w[install show-modules generate-types],
                 'secret' => %w[encrypt decrypt createkeys],
                 'inventory' => %w[show],
                 'group' => %w[show],
                 'project' => %w[init migrate],
                 'apply' => %w[] }.freeze

    attr_reader :config, :options

    def initialize(argv)
      Bolt::Logger.initialize_logging
      @logger = Logging.logger[self]
      @argv = argv
      @config = Bolt::Config.default
      @options = {}
    end

    # Only call after @config has been initialized.
    def inventory
      @inventory ||= Bolt::Inventory.from_config(config, plugins)
    end
    private :inventory

    def help?(remaining)
      # Set the subcommand
      options[:subcommand] = remaining.shift

      if options[:subcommand] == 'help'
        options[:help] = true
        options[:subcommand] = remaining.shift
      end

      # This section handles parsing non-flag options which are
      # subcommand specific rather then part of the config
      actions = COMMANDS[options[:subcommand]]
      if actions && !actions.empty?
        options[:action] = remaining.shift
      end

      options[:help]
    end
    private :help?

    def parse
      parser = BoltOptionParser.new(options)
      # This part aims to handle both `bolt <mode> --help` and `bolt help <mode>`.
      remaining = handle_parser_errors { parser.permute(@argv) } unless @argv.empty?
      if @argv.empty? || help?(remaining)
        # Update the parser for the subcommand (or lack thereof)
        parser.update
        puts parser.help
        raise Bolt::CLIExit
      end

      options[:object] = remaining.shift

      # Only parse task_options for task or plan
      if %w[task plan].include?(options[:subcommand])
        task_options, remaining = remaining.partition { |s| s =~ /.+=/ }
        if options[:task_options]
          unless task_options.empty?
            raise Bolt::CLIError,
                  "Parameters must be specified through either the --params " \
                  "option or param=value pairs, not both"
          end
          options[:params_parsed] = true
        elsif task_options.any?
          options[:params_parsed] = false
          options[:task_options] = Hash[task_options.map { |a| a.split('=', 2) }]
        else
          options[:params_parsed] = true
          options[:task_options] = {}
        end
      end
      options[:leftovers] = remaining

      validate(options)

      @config = if options[:configfile]
                  Bolt::Config.from_file(options[:configfile], options)
                else
                  project = if options[:boltdir]
                              Bolt::Project.create_project(options[:boltdir])
                            else
                              Bolt::Project.find_boltdir(Dir.pwd)
                            end
                  Bolt::Config.from_project(project, options)
                end

      Bolt::Logger.configure(config.log, config.color)

      # Logger must be configured before checking path case and project file, otherwise warnings will not display
      @config.check_path_case('modulepath', @config.modulepath)
      @config.project.check_deprecated_file

      # Log the file paths for loaded config files
      config_loaded

      # Display warnings created during parser and config initialization
      parser.warnings.each { |warning| @logger.warn(warning[:msg]) }
      config.warnings.each { |warning| @logger.warn(warning[:msg]) }

      # After validation, initialize inventory and targets. Errors here are better to catch early.
      # After this step
      # options[:target_args] will contain a string/array version of the targetting options this is passed to plans
      # options[:targets] will contain a resolved set of Target objects
      unless options[:subcommand] == 'puppetfile' ||
             options[:subcommand] == 'secret' ||
             options[:subcommand] == 'project' ||
             options[:action] == 'show' ||
             options[:action] == 'convert'

        update_targets(options)
      end

      unless options.key?(:verbose)
        # Default to verbose for everything except plans
        options[:verbose] = options[:subcommand] != 'plan'
      end

      warn_inventory_overrides_cli(options)
      options
    rescue Bolt::Error => e
      outputter.fatal_error(e)
      raise e
    end

    def update_targets(options)
      target_opts = options.keys.select { |opt| %i[query rerun targets].include?(opt) }
      target_string = "'--targets', '--rerun', or '--query'"
      if target_opts.length > 1
        raise Bolt::CLIError, "Only one targeting option #{target_string} may be specified"
      elsif target_opts.empty? && options[:subcommand] != 'plan'
        raise Bolt::CLIError, "Command requires a targeting option: #{target_string}"
      end

      targets = if options[:query]
                  query_puppetdb_nodes(options[:query])
                elsif options[:rerun]
                  rerun.get_targets(options[:rerun])
                else
                  options[:targets] || []
                end
      options[:target_args] = targets
      options[:targets] = inventory.get_targets(targets)
    end

    def validate(options)
      unless COMMANDS.include?(options[:subcommand])
        raise Bolt::CLIError,
              "Expected subcommand '#{options[:subcommand]}' to be one of " \
              "#{COMMANDS.keys.join(', ')}"
      end

      actions = COMMANDS[options[:subcommand]]
      if actions.any?
        if options[:action].nil?
          raise Bolt::CLIError,
                "Expected an action of the form 'bolt #{options[:subcommand]} <action>'"
        end

        unless actions.include?(options[:action])
          raise Bolt::CLIError,
                "Expected action '#{options[:action]}' to be one of " \
                "#{actions.join(', ')}"
        end
      end

      if options[:subcommand] != 'file' && options[:subcommand] != 'script' &&
         !options[:leftovers].empty?
        raise Bolt::CLIError,
              "Unknown argument(s) #{options[:leftovers].join(', ')}"
      end

      if %w[task plan].include?(options[:subcommand]) && options[:action] == 'run'
        if options[:object].nil?
          raise Bolt::CLIError, "Must specify a #{options[:subcommand]} to run"
        end
        # This may mean that we parsed a parameter as the object
        unless options[:object] =~ /\A([a-z][a-z0-9_]*)?(::[a-z][a-z0-9_]*)*\Z/
          raise Bolt::CLIError,
                "Invalid #{options[:subcommand]} '#{options[:object]}'"
        end
      end

      if options[:boltdir] && options[:configfile]
        raise Bolt::CLIError, "Only one of '--boltdir' or '--configfile' may be specified"
      end

      if options[:noop] &&
         !(options[:subcommand] == 'task' && options[:action] == 'run') && options[:subcommand] != 'apply'
        raise Bolt::CLIError,
              "Option '--noop' may only be specified when running a task or applying manifest code"
      end

      if options[:subcommand] == 'apply' && (options[:object] && options[:code])
        raise Bolt::CLIError, "--execute is unsupported when specifying a manifest file"
      end

      if options[:subcommand] == 'apply' && (!options[:object] && !options[:code])
        raise Bolt::CLIError, "a manifest file or --execute is required"
      end

      if options[:subcommand] == 'command' && (!options[:object] || options[:object].empty?)
        raise Bolt::CLIError, "Must specify a command to run"
      end

      if options[:subcommand] == 'secret' &&
         (options[:action] == 'decrypt' || options[:action] == 'encrypt') &&
         !options[:object]
        raise Bolt::CLIError, "Must specify a value to #{options[:action]}"
      end
    end

    def handle_parser_errors
      yield
    rescue OptionParser::MissingArgument => e
      raise Bolt::CLIError, "Option '#{e.args.first}' needs a parameter"
    rescue OptionParser::InvalidArgument => e
      raise Bolt::CLIError, "Invalid parameter specified for option '#{e.args.first}': #{e.args[1]}"
    rescue OptionParser::InvalidOption, OptionParser::AmbiguousOption => e
      raise Bolt::CLIError, "Unknown argument '#{e.args.first}'"
    end

    def puppetdb_client
      plugins.puppetdb_client
    end

    def plugins
      @plugins ||= Bolt::Plugin.setup(config, pal, analytics)
    end

    def query_puppetdb_nodes(query)
      puppetdb_client.query_certnames(query)
    end

    def warn_inventory_overrides_cli(opts)
      inventory_source = if ENV[Bolt::Inventory::ENVIRONMENT_VAR]
                           Bolt::Inventory::ENVIRONMENT_VAR
                         elsif @config.inventoryfile && Bolt::Util.file_stat(@config.inventoryfile)
                           @config.inventoryfile
                         else
                           begin
                             Bolt::Util.file_stat(@config.default_inventoryfile)
                             @config.default_inventoryfile
                           rescue Errno::ENOENT
                             nil
                           end
                         end

      inventory_cli_opts = %i[authentication escalation transports].each_with_object([]) do |key, acc|
        acc.concat(Bolt::BoltOptionParser::OPTIONS[key])
      end

      inventory_cli_opts.concat(%w[no-host-key-check no-ssl no-ssl-verify no-tty])

      conflicting_options = Set.new(opts.keys.map(&:to_s)).intersection(inventory_cli_opts)

      if inventory_source && conflicting_options.any?
        @logger.warn("CLI arguments #{conflicting_options.to_a} may be overridden by Inventory: #{inventory_source}")
      end
    end

    def execute(options)
      message = nil

      handler = Signal.trap :INT do |signo|
        @logger.info(
          "Exiting after receiving SIG#{Signal.signame(signo)} signal.#{message ? ' ' + message : ''}"
        )
        exit!
      end

      if options[:action] == 'convert'
        convert_plan(options[:object])
        return 0
      end

      screen = "#{options[:subcommand]}_#{options[:action]}"
      # submit a different screen for `bolt task show` and `bolt task show foo`
      if options[:action] == 'show' && options[:object]
        screen += '_object'
      end

      screen_view_fields = {
        output_format: config.format,
        # For continuity
        boltdir_type: config.project.type
      }

      # Only include target and inventory info for commands that take a targets
      # list. This avoids loading inventory for commands that don't need it.
      if options.key?(:targets)
        screen_view_fields.merge!(target_nodes: options[:targets].count,
                                  inventory_nodes: inventory.node_names.count,
                                  inventory_groups: inventory.group_names.count,
                                  inventory_version: inventory.version)
      end

      analytics.screen_view(screen, screen_view_fields)

      if options[:action] == 'show'
        if options[:subcommand] == 'task'
          if options[:object]
            show_task(options[:object])
          else
            list_tasks
          end
        elsif options[:subcommand] == 'plan'
          if options[:object]
            show_plan(options[:object])
          else
            list_plans
          end
        elsif options[:subcommand] == 'inventory'
          if options[:detail]
            show_targets
          else
            list_targets
          end
        elsif options[:subcommand] == 'group'
          list_groups
        end
        return 0
      elsif options[:action] == 'show-modules'
        list_modules
        return 0
      end

      message = 'There may be processes left executing on some nodes.'

      if %w[task plan].include?(options[:subcommand]) && options[:task_options] && !options[:params_parsed] && pal
        options[:task_options] = pal.parse_params(options[:subcommand], options[:object], options[:task_options])
      end

      case options[:subcommand]
      when 'project'
        if options[:action] == 'init'
          code = initialize_project
        elsif options[:action] == 'migrate'
          code = migrate_project
        end
      when 'plan'
        code = run_plan(options[:object], options[:task_options], options[:target_args], options)
      when 'puppetfile'
        if options[:action] == 'generate-types'
          code = generate_types
        elsif options[:action] == 'install'
          code = install_puppetfile(@config.puppetfile_config, @config.puppetfile, @config.modulepath)
        end
      when 'secret'
        code = Bolt::Secret.execute(plugins, outputter, options)
      when 'apply'
        if options[:object]
          validate_file('manifest', options[:object])
          options[:code] = File.read(File.expand_path(options[:object]))
        end
        code = apply_manifest(options[:code], options[:targets], options[:object], options[:noop])
      else
        executor = Bolt::Executor.new(config.concurrency, analytics, options[:noop], config.modified_concurrency)
        targets = options[:targets]

        results = nil
        outputter.print_head

        elapsed_time = Benchmark.realtime do
          executor_opts = {}
          executor_opts[:description] = options[:description] if options.key?(:description)
          executor.subscribe(outputter)
          executor.subscribe(log_outputter)
          results =
            case options[:subcommand]
            when 'command'
              executor.run_command(targets, options[:object], executor_opts)
            when 'script'
              script = options[:object]
              validate_file('script', script)
              executor.run_script(targets, script, options[:leftovers], executor_opts)
            when 'task'
              pal.run_task(options[:object],
                           targets,
                           options[:task_options],
                           executor,
                           inventory,
                           options[:description])
            when 'file'
              src = options[:object]
              dest = options[:leftovers].first

              if dest.nil?
                raise Bolt::CLIError, "A destination path must be specified"
              end
              validate_file('source file', src, true)
              executor.upload_file(targets, src, dest, executor_opts)
            end
        end

        executor.shutdown
        rerun.update(results)

        outputter.print_summary(results, elapsed_time)
        code = results.ok ? 0 : 2
      end
      code
    rescue Bolt::Error => e
      outputter.fatal_error(e)
      raise e
    ensure
      # restore original signal handler
      Signal.trap :INT, handler if handler
      analytics&.finish
    end

    def show_task(task_name)
      outputter.print_task_info(pal.get_task(task_name))
    end

    def list_tasks
      tasks = pal.list_tasks
      tasks.select! { |task| task.first.include?(options[:filter]) } if options[:filter]
      tasks.select! { |task| config.project.tasks.include?(task.first) } unless config.project.tasks.nil?
      outputter.print_tasks(tasks, pal.list_modulepath)
    end

    def show_plan(plan_name)
      outputter.print_plan_info(pal.get_plan_info(plan_name))
    end

    def list_plans
      plans = pal.list_plans
      plans.select! { |plan| plan.first.include?(options[:filter]) } if options[:filter]
      plans.select! { |plan| config.project.plans.include?(plan.first) } unless config.project.plans.nil?
      outputter.print_plans(plans, pal.list_modulepath)
    end

    def list_targets
      update_targets(options)
      outputter.print_targets(options[:targets])
    end

    def show_targets
      update_targets(options)
      outputter.print_target_info(options[:targets])
    end

    def list_groups
      groups = inventory.group_names
      outputter.print_groups(groups)
    end

    def run_plan(plan_name, plan_arguments, nodes, options)
      unless nodes.empty?
        if plan_arguments['nodes'] || plan_arguments['targets']
          key = plan_arguments.include?('nodes') ? 'nodes' : 'targets'
          raise Bolt::CLIError,
                "A plan's '#{key}' parameter may be specified using the --#{key} option, but in that " \
                "case it must not be specified as a separate #{key}=<value> parameter nor included " \
                "in the JSON data passed in the --params option"
        end

        plan_params = pal.get_plan_info(plan_name)['parameters']
        target_param = plan_params.dig('targets', 'type') =~ /TargetSpec/
        node_param = plan_params.include?('nodes')

        if node_param && target_param
          msg = "Plan parameters include both 'nodes' and 'targets' with type 'TargetSpec', " \
                "neither will populated with the value for --nodes or --targets."
          @logger.warn(msg)
        elsif node_param
          plan_arguments['nodes'] = nodes.join(',')
        elsif target_param
          plan_arguments['targets'] = nodes.join(',')
        end
      end

      plan_context = { plan_name: plan_name,
                       params: plan_arguments }
      plan_context[:description] = options[:description] if options[:description]

      executor = Bolt::Executor.new(config.concurrency, analytics, options[:noop], config.modified_concurrency)
      if options.fetch(:format, 'human') == 'human'
        executor.subscribe(outputter)
      else
        # Only subscribe to out::message events for JSON outputter
        executor.subscribe(outputter, [:message])
      end

      executor.subscribe(log_outputter)
      executor.start_plan(plan_context)
      result = pal.run_plan(plan_name, plan_arguments, executor, inventory, puppetdb_client)

      # If a non-bolt exception bubbles up the plan won't get finished
      executor.finish_plan(result)
      executor.shutdown
      rerun.update(result)

      outputter.print_plan_result(result)
      result.ok? ? 0 : 1
    end

    def apply_manifest(code, targets, filename = nil, noop = false)
      Puppet[:tasks] = false
      ast = pal.parse_manifest(code, filename)

      if defined?(ast.body) &&
         (ast.body.is_a?(Puppet::Pops::Model::HostClassDefinition) ||
         ast.body.is_a?(Puppet::Pops::Model::ResourceTypeDefinition))
        message = "Manifest only contains definitions and will result in no changes on the targets. "\
                  "Definitions must be declared for their resources to be applied. You can read more "\
                  "about defining and declaring classes and types in the Puppet documentation at "\
                  "https://puppet.com/docs/puppet/latest/lang_classes.html and "\
                  "https://puppet.com/docs/puppet/latest/lang_defined_types.html"
        @logger.warn(message)
      end

      executor = Bolt::Executor.new(config.concurrency, analytics, noop, config.modified_concurrency)
      executor.subscribe(outputter) if options.fetch(:format, 'human') == 'human'
      executor.subscribe(log_outputter)
      # apply logging looks like plan logging, so tell the outputter we're in a
      # plan even though we're not
      executor.publish_event(type: :plan_start, plan: nil)

      results = nil
      elapsed_time = Benchmark.realtime do
        pal.in_plan_compiler(executor, inventory, puppetdb_client) do |compiler|
          compiler.call_function('apply_prep', targets)
        end

        results = pal.with_bolt_executor(executor, inventory, puppetdb_client) do
          Puppet.lookup(:apply_executor).apply_ast(ast, targets, catch_errors: true, noop: noop)
        end
      end

      executor.shutdown
      outputter.print_apply_result(results, elapsed_time)
      rerun.update(results)

      results.ok ? 0 : 1
    end

    def list_modules
      outputter.print_module_list(pal.list_modules)
    end

    def generate_types
      # generate_types will surface a nice error with helpful message if it fails
      pal.generate_types
      0
    end

    # Initializes a specified directory as a Bolt project and installs any modules
    # specified by the user, along with their dependencies
    def initialize_project
      project    = Pathname.new(File.expand_path(options[:object] || Dir.pwd))
      config     = project + 'bolt.yaml'
      puppetfile = project + 'Puppetfile'
      modulepath = [project + 'modules']

      # If modules were specified, first check if there is already a Puppetfile at the project
      # directory, erroring if there is. If there is no Puppetfile, generate the Puppetfile
      # content by resolving the specified modules and all their dependencies.
      # We generate the Puppetfile first so that any errors in resolving modules and their
      # dependencies are caught early and do not create a project directory.
      if options[:modules]
        if puppetfile.exist?
          raise Bolt::CLIError,
                "Found existing Puppetfile at #{puppetfile}, unable to initialize project with "\
                "#{options[:modules].join(', ')}"
        else
          puppetfile_specs = resolve_puppetfile_specs
        end
      end

      # Warn the user if the project directory already exists. We don't error here since users
      # might not have installed any modules yet.
      if config.exist?
        @logger.warn "Found existing project directory at #{project}"
      end

      # Create the project directory
      FileUtils.mkdir_p(project)

      # Bless the project directory as a...wait for it...project
      if FileUtils.touch(config)
        outputter.print_message "Successfully created Bolt project at #{project}"
      else
        raise Bolt::FileError.new("Could not create Bolt project directory at #{project}", nil)
      end

      # Write the generated Puppetfile to the fancy new project
      if puppetfile_specs
        File.write(puppetfile, puppetfile_specs.join("\n"))
        outputter.print_message "Successfully created Puppetfile at #{puppetfile}"
        # Install the modules from our shiny new Puppetfile
        if install_puppetfile({}, puppetfile, modulepath)
          outputter.print_message "Successfully installed #{options[:modules].join(', ')}"
        else
          raise Bolt::CLIError, "Could not install #{options[:modules].join(', ')}"
        end
      end

      0
    end

    # Resolves Puppetfile specs from user-specified modules and dependencies resolved
    # by the puppetfile-resolver gem.
    def resolve_puppetfile_specs
      require 'puppetfile-resolver'

      # Build the document model from the module names, defaulting to the latest version of each module
      model = PuppetfileResolver::Puppetfile::Document.new('')
      options[:modules].each do |mod_name|
        model.add_module(
          PuppetfileResolver::Puppetfile::ForgeModule.new(mod_name).tap { |mod| mod.version = :latest }
        )
      end

      # Make sure the Puppetfile model is valid
      unless model.valid?
        raise Bolt::ValidationError,
              "Unable to resolve dependencies for #{options[:modules].join(', ')}"
      end

      # Create the resolver using the Puppetfile model. nil disables Puppet version restrictions.
      resolver = PuppetfileResolver::Resolver.new(model, nil)

      # Configure and resolve the dependency graph
      result = resolver.resolve(
        cache:                 nil,
        ui:                    nil,
        module_paths:          [],
        allow_missing_modules: true
      )

      # Validate that the modules exist
      missing_graph = result.specifications.select do |_name, spec|
        spec.instance_of? PuppetfileResolver::Models::MissingModuleSpecification
      end

      if missing_graph.any?
        titles = model.modules.each_with_object({}) do |mod, acc|
          acc[mod.name] = mod.title
        end

        names = titles.values_at(*missing_graph.keys)
        plural = names.count == 1 ? '' : 's'

        raise Bolt::ValidationError,
              "Unknown module name#{plural} #{names.join(', ')}"
      end

      # Filter the dependency graph to only include module specifications
      spec_graph = result.specifications.select do |_name, spec|
        spec.instance_of? PuppetfileResolver::Models::ModuleSpecification
      end

      # Map specification models to a Puppetfile specification
      spec_graph.values.map do |spec|
        "mod '#{spec.owner}-#{spec.name}', '#{spec.version}'"
      end
    end

    def migrate_project
      inventory_file = config.inventoryfile || config.default_inventoryfile
      data = Bolt::Util.read_yaml_hash(inventory_file, 'inventory')

      data.delete('version') if data['version'] != 2

      migrated = migrate_group(data)

      ok = File.write(inventory_file, data.to_yaml) if migrated

      result = if migrated && ok
                 "Successfully migrated Bolt project to latest version."
               elsif !migrated
                 "Bolt project already on latest version. Nothing to do."
               else
                 "Could not migrate Bolt project to latest version."
               end
      outputter.print_message result

      ok ? 0 : 1
    end

    # Walks an inventory hash and replaces all 'nodes' keys with 'targets' keys
    # and all 'name' keys nested in a 'targets' hash with 'uri' keys. Data is
    # modified in place.
    def migrate_group(group)
      migrated = false
      if group.key?('nodes')
        migrated = true
        targets = group['nodes'].map do |target|
          target['uri'] = target.delete('name') if target.is_a?(Hash)
          target
        end
        group.delete('nodes')
        group['targets'] = targets
      end
      (group['groups'] || []).each do |subgroup|
        migrated_group = migrate_group(subgroup)
        migrated ||= migrated_group
      end
      migrated
    end

    def install_puppetfile(config, puppetfile, modulepath)
      require 'r10k/cli'
      require 'bolt/r10k_log_proxy'

      if puppetfile.exist?
        moduledir = modulepath.first.to_s
        r10k_opts = {
          root: puppetfile.dirname.to_s,
          puppetfile: puppetfile.to_s,
          moduledir: moduledir
        }

        settings = R10K::Settings.global_settings.evaluate(config)
        R10K::Initializers::GlobalInitializer.new(settings).call
        install_action = R10K::Action::Puppetfile::Install.new(r10k_opts, nil)

        # Override the r10k logger with a proxy to our own logger
        R10K::Logging.instance_variable_set(:@outputter, Bolt::R10KLogProxy.new)

        ok = install_action.call
        outputter.print_puppetfile_result(ok, puppetfile, moduledir)
        # Automatically generate types after installing modules
        pal.generate_types

        ok ? 0 : 1
      else
        raise Bolt::FileError.new("Could not find a Puppetfile at #{puppetfile}", puppetfile)
      end
    rescue R10K::Error => e
      raise PuppetfileError, e
    end

    def pal
      project = config.project.project_file? ? config.project : nil
      @pal ||= Bolt::PAL.new(config.modulepath,
                             config.hiera_config,
                             config.project.resource_types,
                             config.compile_concurrency,
                             config.trusted_external,
                             config.apply_settings,
                             project)
    end

    def convert_plan(plan)
      pal.convert_plan(plan)
    end

    def validate_file(type, path, allow_dir = false)
      if path.nil?
        raise Bolt::CLIError, "A #{type} must be specified"
      end

      Bolt::Util.validate_file(type, path, allow_dir)
    end

    def rerun
      @rerun ||= Bolt::Rerun.new(@config.rerunfile, @config.save_rerun)
    end

    def outputter
      @outputter ||= Bolt::Outputter.for_format(config.format, config.color, options[:verbose], config.trace)
    end

    def log_outputter
      @log_outputter ||= Bolt::Outputter::Logger.new(options[:verbose], config.trace)
    end

    def analytics
      @analytics ||= begin
                       client = Bolt::Analytics.build_client
                       client.bundled_content = bundled_content
                       client
                     end
    end

    def bundled_content
      # If the bundled content directory is empty, Bolt is likely installed as a gem.
      if ENV['BOLT_GEM'].nil? && incomplete_install?
        msg = <<~MSG.chomp
          Bolt may be installed as a gem. To use Bolt reliably and with all of its
          dependencies, uninstall the 'bolt' gem and install Bolt as a package:
          https://puppet.com/docs/bolt/latest/bolt_installing.html

          If you meant to install Bolt as a gem and want to disable this warning,
          set the BOLT_GEM environment variable.
        MSG

        @logger.warn(msg)
      end

      # We only need to enumerate bundled content when running a task or plan
      content = { 'Plan' => [],
                  'Task' => [],
                  'Plugin' => Bolt::Plugin::BUILTIN_PLUGINS }
      if %w[plan task].include?(options[:subcommand]) && options[:action] == 'run'
        default_content = Bolt::PAL.new([], nil, nil)
        content['Plan'] = default_content.list_plans.each_with_object([]) do |iter, col|
          col << iter&.first
        end
        content['Task'] = default_content.list_tasks.each_with_object([]) do |iter, col|
          col << iter&.first
        end
      end

      content
    end

    def config_loaded
      msg = <<~MSG.chomp
        Loaded configuration from: '#{config.config_files.join("', '")}'
      MSG
      @logger.debug(msg)
    end

    # Gem installs include the aggregate, canary, and puppetdb_fact modules, while
    # package installs include modules listed in the Bolt repo Puppetfile
    def incomplete_install?
      (Dir.children(Bolt::PAL::MODULES_PATH) - %w[aggregate canary puppetdb_fact]).empty?
    end
  end
end
