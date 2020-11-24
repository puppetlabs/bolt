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
require 'bolt/logger'
require 'bolt/module_installer'
require 'bolt/outputter'
require 'bolt/pal'
require 'bolt/plan_creator'
require 'bolt/plugin'
require 'bolt/project_manager'
require 'bolt/puppetdb'
require 'bolt/rerun'
require 'bolt/secret'
require 'bolt/target'
require 'bolt/version'

module Bolt
  class CLIExit < StandardError; end

  class CLI
    COMMANDS = {
      'command'    => %w[run],
      'script'     => %w[run],
      'task'       => %w[show run],
      'plan'       => %w[show run convert new],
      'file'       => %w[download upload],
      'puppetfile' => %w[install show-modules generate-types],
      'secret'     => %w[encrypt decrypt createkeys],
      'inventory'  => %w[show],
      'group'      => %w[show],
      'project'    => %w[init migrate],
      'module'     => %w[add generate-types install show],
      'apply'      => %w[],
      'guide'      => %w[]
    }.freeze

    attr_reader :config, :options

    def initialize(argv)
      Bolt::Logger.initialize_logging
      @logger = Bolt::Logger.logger(self)
      @argv = argv
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

    # Wrapper method that is called by the Bolt executable. Parses the command and
    # then loads the project and config. Once config is loaded, it completes the
    # setup process by configuring Bolt and logging messages.
    #
    # This separation is needed since the Bolt::Outputter class that normally handles
    # printing errors relies on config being loaded. All setup that happens before
    # config is loaded will have errors printed directly to stdout, while all errors
    # raised after config is loaded are handled by the outputter.
    def parse
      parse_command
      load_config
      finalize_setup
    end

    # Parses the command and validates options. All errors that are raised here
    # are not handled by the outputter, as it relies on config being loaded.
    def parse_command
      parser = BoltOptionParser.new(options)
      # This part aims to handle both `bolt <mode> --help` and `bolt help <mode>`.
      remaining = handle_parser_errors { parser.permute(@argv) } unless @argv.empty?
      if @argv.empty? || help?(remaining)
        # If the subcommand is not enabled, display the default
        # help text
        options[:subcommand] = nil unless COMMANDS.include?(options[:subcommand])

        # Update the parser for the subcommand (or lack thereof)
        parser.update
        puts parser.help
        raise Bolt::CLIExit
      end

      options[:object] = remaining.shift

      # Handle reading a command from a file
      if options[:subcommand] == 'command' && options[:object]
        options[:object] = Bolt::Util.get_arg_input(options[:object])
      end

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

      # Default to verbose for everything except plans
      unless options.key?(:verbose)
        options[:verbose] = options[:subcommand] != 'plan'
      end

      validate(options)

      # Deprecation warnings can't be issued until after config is loaded, so
      # store them for later.
      @parser_deprecations = parser.deprecations
    rescue Bolt::Error => e
      fatal_error(e)
      raise e
    end

    # Loads the project and configuration. All errors that are raised here are not
    # handled by the outputter, as it relies on config being loaded.
    def load_config
      @config = if ENV['BOLT_PROJECT']
                  project = Bolt::Project.create_project(ENV['BOLT_PROJECT'], 'environment')
                  Bolt::Config.from_project(project, options)
                elsif options[:configfile]
                  Bolt::Config.from_file(options[:configfile], options)
                else
                  cli_flag = options[:project] || options[:boltdir]
                  project = if cli_flag
                              dir = Pathname.new(cli_flag)
                              if (dir + Bolt::Project::BOLTDIR_NAME).directory?
                                Bolt::Project.create_project(dir + Bolt::Project::BOLTDIR_NAME)
                              else
                                Bolt::Project.create_project(dir)
                              end
                            else
                              Bolt::Project.find_boltdir(Dir.pwd)
                            end
                  Bolt::Config.from_project(project, options)
                end
    rescue Bolt::Error => e
      fatal_error(e)
      raise e
    end

    # Completes the setup process by configuring Bolt and log messages
    def finalize_setup
      Bolt::Logger.configure(config.log, config.color)
      Bolt::Logger.analytics = analytics

      # Logger must be configured before checking path case and project file, otherwise logs will not display
      config.check_path_case('modulepath', config.modulepath)
      config.project.check_deprecated_file

      # Log messages created during parser and config initialization
      config.logs.each { |log| @logger.send(log.keys[0], log.values[0]) }
      @parser_deprecations.each { |dep| Bolt::Logger.deprecation_warning(dep[:type], dep[:msg]) }
      config.deprecations.each { |dep| Bolt::Logger.deprecation_warning(dep[:type], dep[:msg]) }

      warn_inventory_overrides_cli(options)
      validate_ps_version

      options
    rescue Bolt::Error => e
      outputter.fatal_error(e)
      raise e
    end

    private def validate_ps_version
      if Bolt::Util.powershell?
        target = inventory.get_target('localhost')
        Bolt::Transport::Local.new.with_connection(target) do |conn|
          # This will automatically validate the powershell version on the Bolt
          # controller
          Bolt::Shell::Powershell.new(target, conn)
        end
      end
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
        command = Bolt::Util.powershell? ? 'Get-Command -Module PuppetBolt' : 'bolt help'
        raise Bolt::CLIError,
              "'#{options[:subcommand]}' is not a Bolt command. See '#{command}'."
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

      if options[:subcommand] == 'plan' && options[:action] == 'new' && !options[:object]
        raise Bolt::CLIError, "Must specify a plan name."
      end

      if options[:subcommand] == 'module' && options[:action] == 'add' && !options[:object]
        raise Bolt::CLIError, "Must specify a module name."
      end

      if options[:subcommand] == 'module' && options[:action] == 'install' && options[:object]
        command = Bolt::Util.powershell? ? 'Add-BoltModule -Module' : 'bolt module add'
        raise Bolt::CLIError, "Invalid argument '#{options[:object]}'. To add a new module to "\
                              "the project, run '#{command} #{options[:object]}'."
      end

      if options[:subcommand] != 'file' && options[:subcommand] != 'script' &&
         !options[:leftovers].empty?
        raise Bolt::CLIError,
              "Unknown argument(s) #{options[:leftovers].join(', ')}"
      end

      if options.slice(:boltdir, :configfile, :project).length > 1
        raise Bolt::CLIError, "Only one of '--boltdir', '--project', or '--configfile' may be specified"
      end

      if options[:noop] &&
         !(options[:subcommand] == 'task' && options[:action] == 'run') && options[:subcommand] != 'apply'
        raise Bolt::CLIError,
              "Option '--noop' may only be specified when running a task or applying manifest code"
      end

      if options[:env_vars]
        unless %w[command script].include?(options[:subcommand]) && options[:action] == 'run'
          raise Bolt::CLIError,
                "Option '--env-var' may only be specified when running a command or script"
        end
      end

      if options.key?(:debug) && options.key?(:log)
        raise Bolt::CLIError, "Only one of '--debug' or '--log-level' may be specified"
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
                         elsif config.inventoryfile
                           config.inventoryfile
                         elsif File.exist?(config.default_inventoryfile)
                           config.default_inventoryfile
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

      # Initialize inventory and targets. Errors here are better to catch early.
      # options[:target_args] will contain a string/array version of the targetting options this is passed to plans
      # options[:targets] will contain a resolved set of Target objects
      unless %w[guide module project puppetfile secret].include?(options[:subcommand]) ||
             %w[convert new show].include?(options[:action])
        update_targets(options)
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
      }.merge!(analytics.plan_counts(config.project.plans_path))

      # Only include target and inventory info for commands that take a targets
      # list. This avoids loading inventory for commands that don't need it.
      if options.key?(:targets)
        screen_view_fields.merge!(target_nodes: options[:targets].count,
                                  inventory_nodes: inventory.node_names.count,
                                  inventory_groups: inventory.group_names.count,
                                  inventory_version: inventory.version)
      end

      analytics.screen_view(screen, **screen_view_fields)

      case options[:action]
      when 'show'
        case options[:subcommand]
        when 'task'
          if options[:object]
            show_task(options[:object])
          else
            list_tasks
          end
        when 'plan'
          if options[:object]
            show_plan(options[:object])
          else
            list_plans
          end
        when 'inventory'
          if options[:detail]
            show_targets
          else
            list_targets
          end
        when 'group'
          list_groups
        when 'module'
          list_modules
        end
        return 0
      when 'show-modules'
        list_modules
        return 0
      when 'convert'
        pal.convert_plan(options[:object])
        return 0
      end

      message = 'There may be processes left executing on some nodes.'

      if %w[task plan].include?(options[:subcommand]) && options[:task_options] && !options[:params_parsed] && pal
        options[:task_options] = pal.parse_params(options[:subcommand], options[:object], options[:task_options])
      end

      case options[:subcommand]
      when 'guide'
        code = if options[:object]
                 show_guide(options[:object])
               else
                 list_topics
               end
      when 'project'
        case options[:action]
        when 'init'
          code = Bolt::ProjectManager.new(config, outputter, pal)
                                     .create(Dir.pwd, options[:object], options[:modules])
        when 'migrate'
          code = Bolt::ProjectManager.new(config, outputter, pal).migrate
        end
      when 'plan'
        case options[:action]
        when 'new'
          plan_name = options[:object]

          # If this passes validation, it will return the path to the plan to create
          Bolt::PlanCreator.validate_input(config.project, plan_name)
          code = Bolt::PlanCreator.create_plan(config.project.plans_path,
                                               plan_name,
                                               outputter,
                                               options[:puppet])
        when 'run'
          code = run_plan(options[:object], options[:task_options], options[:target_args], options)
        end
      when 'module'
        case options[:action]
        when 'add'
          code = add_project_module(options[:object], config.project)
        when 'install'
          code = install_project_modules(config.project, options[:force], options[:resolve])
        when 'generate-types'
          code = generate_types
        end
      when 'puppetfile'
        case options[:action]
        when 'generate-types'
          code = generate_types
        when 'install'
          code = install_puppetfile(
            config.puppetfile_config,
            config.puppetfile,
            config.modulepath.first
          )
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
          executor_opts[:env_vars] = options[:env_vars] if options.key?(:env_vars)
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

              if src.nil?
                raise Bolt::CLIError, "A source path must be specified"
              end

              if dest.nil?
                raise Bolt::CLIError, "A destination path must be specified"
              end

              case options[:action]
              when 'download'
                dest = File.expand_path(dest, Dir.pwd)
                executor.download_file(targets, src, dest, executor_opts)
              when 'upload'
                validate_file('source file', src, true)
                executor.upload_file(targets, src, dest, executor_opts)
              end
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

    # Filters a list of content by matching substring.
    #
    private def filter_content(content, filter)
      return content unless content && filter
      content.select { |name,| name.include?(filter) }
    end

    def list_tasks
      tasks = filter_content(pal.list_tasks(filter_content: true), options[:filter])
      outputter.print_tasks(tasks, pal.user_modulepath)
    end

    def show_plan(plan_name)
      outputter.print_plan_info(pal.get_plan_info(plan_name))
    end

    def list_plans
      plans = filter_content(pal.list_plans(filter_content: true), options[:filter])
      outputter.print_plans(plans, pal.user_modulepath)
    end

    def list_targets
      inventoryfile = config.inventoryfile || config.default_inventoryfile

      # Retrieve the known group and target names. This needs to be done before
      # updating targets, as that will add adhoc targets to the inventory.
      known_names = inventory.target_names

      update_targets(options)

      inventory_targets, adhoc_targets = options[:targets].partition do |target|
        known_names.include?(target.name)
      end

      target_list = {
        inventory: inventory_targets,
        adhoc:     adhoc_targets
      }

      outputter.print_targets(target_list, inventoryfile)
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
      if %w[human rainbow].include?(options.fetch(:format, 'human'))
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
      assert_puppetfile_or_module_command(config.project.modules)
      outputter.print_module_list(pal.list_modules)
    end

    def generate_types
      assert_puppetfile_or_module_command(config.project.modules)
      # generate_types will surface a nice error with helpful message if it fails
      pal.generate_types
      0
    end

    # Installs modules declared in the project configuration file.
    #
    def install_project_modules(project, force, resolve)
      assert_project_file(project)
      assert_puppetfile_or_module_command(project.modules)

      unless project.modules
        outputter.print_message "Project configuration file #{project.project_file} does not "\
                                "specify any module dependencies. Nothing to do."
        return 0
      end

      installer = Bolt::ModuleInstaller.new(outputter, pal)

      ok = installer.install(project.modules,
                             project.puppetfile,
                             project.managed_moduledir,
                             force: force,
                             resolve: resolve)
      ok ? 0 : 1
    end

    # Adds a single module to the project.
    #
    def add_project_module(name, project)
      assert_project_file(project)
      assert_puppetfile_or_module_command(project.modules)

      modules   = project.modules || []
      installer = Bolt::ModuleInstaller.new(outputter, pal)

      ok = installer.add(name,
                         modules,
                         project.puppetfile,
                         project.managed_moduledir,
                         project.project_file)
      ok ? 0 : 1
    end

    # Asserts that there is a project configuration file.
    #
    def assert_project_file(project)
      unless project.project_file?
        msg = if project.config_file.exist?
                command = Bolt::Util.powershell? ? 'Update-BoltProject' : 'bolt project migrate'
                "Detected Bolt configuration file #{project.config_file}, unable to install "\
                "modules. To update to a project configuration file, run '#{command}'."
              else
                command = Bolt::Util.powershell? ? 'New-BoltProject' : 'bolt project init'
                "Could not find project configuration file #{project.project_file}, unable "\
                "to install modules. To create a Bolt project, run '#{command}'."
              end

        raise Bolt::Error.new(msg, 'bolt/missing-project-config-error')
      end
    end

    # Loads a Puppetfile and installs its modules.
    #
    def install_puppetfile(puppetfile_config, puppetfile, moduledir)
      assert_puppetfile_or_module_command(config.project.modules)

      outputter.print_message("Installing modules from Puppetfile")
      installer = Bolt::ModuleInstaller.new(outputter, pal)
      ok = installer.install_puppetfile(puppetfile, moduledir, puppetfile_config)
      ok ? 0 : 1
    end

    # Raises an error if the 'puppetfile install' command is deprecated due to
    # modules being configured.
    #
    def assert_puppetfile_or_module_command(modules)
      if Bolt::Util.powershell?
        case options[:action]
        when 'generate-types'
          old_command = 'Register-BoltPuppetfileTypes'
          new_command = 'Register-BoltModuleTypes'
        when 'install'
          old_command = 'Install-BoltPuppetfile'
          new_command = 'Install-BoltModule'
        when 'show', 'show-modules'
          old_command = 'Get-BoltPuppetfileModules'
          new_command = 'Get-BoltModule'
        end
      else
        old_command = "bolt puppetfile #{options[:action]}"
        new_command = if options[:action] == 'show-modules'
                        'bolt module show'
                      else
                        "bolt module #{options[:action]}"
                      end
      end

      if modules && options[:subcommand] == 'puppetfile'
        raise Bolt::CLIError,
              "Unable to use command '#{old_command}' when 'modules' is configured in "\
              "bolt-project.yaml. Use '#{new_command}' instead."
      elsif modules.nil? && options[:subcommand] == 'module'
        msg  = "Unable to use command '#{new_command}' when 'modules' is not configured in "\
               "bolt-project.yaml. "
        msg += "Use '#{old_command}' instead." if options[:action] != 'add'
        raise Bolt::CLIError, msg
      end
    end

    def pal
      @pal ||= Bolt::PAL.new(Bolt::Config::Modulepath.new(config.modulepath),
                             config.hiera_config,
                             config.project.resource_types,
                             config.compile_concurrency,
                             config.trusted_external,
                             config.apply_settings,
                             config.project)
    end

    # Collects the list of Bolt guides and maps them to their topics.
    def guides
      @guides ||= begin
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
    end

    # Display the list of available Bolt guides.
    def list_topics
      outputter.print_topics(guides.keys)
      0
    end

    # Display a specific Bolt guide.
    def show_guide(topic)
      if guides[topic]
        analytics.event('Guide', 'known_topic', label: topic)

        begin
          guide = File.read(guides[topic])
        rescue SystemCallError => e
          raise Bolt::FileError("#{e.message}: unable to load guide page", filepath)
        end

        outputter.print_guide(guide, topic)
      else
        analytics.event('Guide', 'unknown_topic', label: topic)
        outputter.print_message("Did not find guide for topic '#{topic}'.\n\n")
        list_topics
      end
      0
    end

    def validate_file(type, path, allow_dir = false)
      if path.nil?
        raise Bolt::CLIError, "A #{type} must be specified"
      end

      Bolt::Util.validate_file(type, path, allow_dir)
    end

    def rerun
      @rerun ||= Bolt::Rerun.new(config.rerunfile, config.save_rerun)
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
        default_content = Bolt::PAL.new(Bolt::Config::Modulepath.new([]), nil, nil)
        content['Plan'] = default_content.list_plans.each_with_object([]) do |iter, col|
          col << iter&.first
        end
        content['Task'] = default_content.list_tasks.each_with_object([]) do |iter, col|
          col << iter&.first
        end
      end

      content
    end

    # Gem installs include the aggregate, canary, and puppetdb_fact modules, while
    # package installs include modules listed in the Bolt repo Puppetfile
    def incomplete_install?
      (Dir.children(Bolt::Config::Modulepath::MODULES_PATH) - %w[aggregate canary puppetdb_fact secure_env_vars]).empty?
    end

    # Mimicks the output from Outputter::Human#fatal_error. This should be used to print
    # errors prior to config being loaded, as the outputter relies on config being loaded.
    def fatal_error(error)
      if $stdout.isatty
        $stdout.puts("\033[31m#{error.message}\033[0m")
      else
        $stdout.puts(error.message)
      end
    end
  end
end
