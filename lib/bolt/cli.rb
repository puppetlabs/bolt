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
      'apply'     => %w[],
      'command'   => %w[run],
      'file'      => %w[download upload],
      'group'     => %w[show],
      'guide'     => %w[],
      'inventory' => %w[show],
      'lookup'    => %w[],
      'module'    => %w[add generate-types install show],
      'plan'      => %w[show run convert new],
      'plugin'    => %w[show],
      'project'   => %w[init migrate],
      'script'    => %w[run],
      'secret'    => %w[encrypt decrypt createkeys],
      'task'      => %w[show run]
    }.freeze

    TARGETING_OPTIONS = %i[query rerun targets].freeze

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

    # Prints a welcome message when users first install Bolt and run `bolt`, `bolt help` or `bolt --help`
    def welcome_message
      bolt = <<~BOLT
                   `.::-`
              `.-:///////-.`
           `-:////:.  `-:///:-  /ooo.                        .ooo/
       `.-:///::///:-`   `-//:  ymmm-                        :mmmy  .---.
      :///:-.   `.:////.  -//:  ymmm-                        :mmmy  +mmm+
      ://.          ///.  -//:  ymmm--/++/-       `-/++/:`   :mmmy-:smmms::-
      ://.          ://. .://:  ymmmdmmmmmmdo`  .smmmmmmmmh: :mmmysmmmmmmmms
      ://.          ://:///:-.  ymmmh/--/hmmmy -mmmd/-.:hmmm+:mmmy.-smmms--.
      ://:.`      .-////:-`     ymmm-     ymmm:hmmm-    `dmmm/mmmy  +mmm+
      `-:///:-..:///:-.`        ymmm-     ommm/dmmm`     hmmm+mmmy  +mmm+
         `.-:////:-`            ymmm+    /mmmm.ommms`   /mmmh:mmmy  +mmmo
             `-.`               ymmmmmhhmmmmd:  ommmmhydmmmy`:mmmy  -mmmmdhd
                                oyyy+shddhs/`    .+shddhy+-  -yyyo   .ohddhs


      BOLT
      example_cmd = if Bolt::Util.windows?
                      "Invoke-BoltCommand -Command 'hostname' -Targets localhost"
                    else
                      "bolt command run 'hostname' --target localhost"
                    end
      prev_cmd = String.new("bolt")
      prev_cmd << " #{@argv[0]}" unless @argv.empty?

      message = <<~MSG
      🎉 Welcome to Bolt #{VERSION}
      😌 We're here to help bring order to the chaos
      📖 Find our documentation at https://bolt.guide
      🙋 Ask a question in #bolt on https://slack.puppet.com/
      🔩 Contribute at https://github.com/puppetlabs/bolt/
      💡 Not sure where to start? Try "#{example_cmd}"

      We only print this message once. Run "#{prev_cmd}" again for help text.
      MSG

      $stdout.print "\033[36m#{bolt}\033[0m"
      $stdout.print message
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

        if Bolt::Util.first_run?
          FileUtils.touch(Bolt::Util.first_runs_free)

          if options[:subcommand].nil? && $stdout.isatty
            welcome_message
            raise Bolt::CLIExit
          end
        end

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
    rescue Bolt::Error => e
      fatal_error(e)
      raise e
    end

    # Loads the project and configuration. All errors that are raised here are not
    # handled by the outputter, as it relies on config being loaded.
    def load_config
      project = if ENV['BOLT_PROJECT']
                  Bolt::Project.create_project(ENV['BOLT_PROJECT'], 'environment')
                elsif options[:project]
                  dir = Pathname.new(options[:project])
                  if (dir + Bolt::Project::BOLTDIR_NAME).directory?
                    Bolt::Project.create_project(dir + Bolt::Project::BOLTDIR_NAME)
                  else
                    Bolt::Project.create_project(dir)
                  end
                else
                  Bolt::Project.find_boltdir(Dir.pwd)
                end
      @config = Bolt::Config.from_project(project, options)
    rescue Bolt::Error => e
      fatal_error(e)
      raise e
    end

    # Completes the setup process by configuring Bolt and log messages
    def finalize_setup
      Bolt::Logger.configure(config.log, config.color, config.disable_warnings)
      Bolt::Logger.stream = config.stream
      Bolt::Logger.analytics = analytics
      Bolt::Logger.flush_queue

      # Logger must be configured before checking path case and project file, otherwise logs will not display
      config.check_path_case('modulepath', config.modulepath)
      config.project.check_deprecated_file

      if options[:clear_cache]
        FileUtils.rm(config.project.plugin_cache_file) if File.exist?(config.project.plugin_cache_file)
        FileUtils.rm(config.project.task_cache_file) if File.exist?(config.project.task_cache_file)
        FileUtils.rm(config.project.plan_cache_file) if File.exist?(config.project.plan_cache_file)
      end

      warn_inventory_overrides_cli(options)
      validate_ps_version

      options
    rescue Bolt::Error => e
      outputter.fatal_error(e)
      raise e
    end

    private def validate_ps_version
      if Bolt::Util.powershell?
        command = "powershell.exe -NoProfile -NonInteractive -NoLogo -ExecutionPolicy "\
                  "Bypass -Command $PSVersionTable.PSVersion.Major"
        stdout, _stderr, _status = Open3.capture3(command)

        return unless !stdout.empty? && stdout.to_i < 3

        msg = "Detected PowerShell 2 on controller. PowerShell 2 is unsupported."
        Bolt::Logger.deprecation_warning("powershell_2_controller", msg)
      end
    end

    def update_targets(options)
      target_opts = options.keys.select { |opt| TARGETING_OPTIONS.include?(opt) }
      target_string = "'--targets', '--rerun', or '--query'"
      if target_opts.length > 1
        raise Bolt::CLIError, "Only one targeting option #{target_string} can be specified"
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

      if %w[task plan script].include?(options[:subcommand]) && options[:action] == 'run'
        if options[:object].nil?
          raise Bolt::CLIError, "Must specify a #{options[:subcommand]} to run"
        end
      end

      # This may mean that we parsed a parameter as the object
      if %w[task plan].include?(options[:subcommand]) && options[:action] == 'run'
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

      if options[:subcommand] == 'lookup' && !options[:object]
        raise Bolt::CLIError, "Must specify a key to look up"
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

      if !%w[file script lookup].include?(options[:subcommand]) &&
         !options[:leftovers].empty?
        raise Bolt::CLIError,
              "Unknown argument(s) #{options[:leftovers].join(', ')}"
      end

      target_opts = options.keys.select { |opt| TARGETING_OPTIONS.include?(opt) }
      if options[:subcommand] == 'lookup' &&
         target_opts.any? && options[:plan_hierarchy]
        raise Bolt::CLIError, "The 'lookup' command accepts either targeting option OR --plan-hierarchy."
      end

      if options[:noop] &&
         !(options[:subcommand] == 'task' && options[:action] == 'run') && options[:subcommand] != 'apply'
        raise Bolt::CLIError,
              "Option '--noop' can only be specified when running a task or applying manifest code"
      end

      if options[:env_vars]
        unless %w[command script].include?(options[:subcommand]) && options[:action] == 'run'
          raise Bolt::CLIError,
                "Option '--env-var' can only be specified when running a command or script"
        end
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
        Bolt::Logger.warn(
          "cli_overrides",
          "CLI arguments #{conflicting_options.to_a} might be overridden by Inventory: #{inventory_source}"
        )
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
      # options[:target_args] will contain a string/array version of the targeting options this is passed to plans
      # options[:targets] will contain a resolved set of Target objects
      unless %w[guide module project secret].include?(options[:subcommand]) ||
             %w[convert new show].include?(options[:action]) ||
             options[:plan_hierarchy]
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
          if options[:object]
            show_module(options[:object])
          else
            list_modules
          end
        when 'plugin'
          list_plugins
        end
        return 0
      when 'convert'
        pal.convert_plan(options[:object])
        return 0
      end

      message = 'There might be processes left executing on some nodes.'

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
      when 'lookup'
        plan_vars = Hash[options[:leftovers].map { |a| a.split('=', 2) }]
        # Validate functions verifies one of these was passed
        if options[:targets]
          code = lookup(options[:object], options[:targets], plan_vars: plan_vars)
        elsif options[:plan_hierarchy]
          code = plan_lookup(options[:object], plan_vars: plan_vars)
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
          code = add_project_module(options[:object], config.project, config.module_install)
        when 'install'
          code = install_project_modules(config.project, config.module_install, options[:force], options[:resolve])
        when 'generate-types'
          code = generate_types
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
        executor = Bolt::Executor.new(config.concurrency,
                                      analytics,
                                      options[:noop],
                                      config.modified_concurrency,
                                      config.future)
        targets = options[:targets]

        results = nil
        outputter.print_head

        elapsed_time = Benchmark.realtime do
          executor_opts = {}
          executor_opts[:env_vars] = options[:env_vars] if options.key?(:env_vars)
          executor.subscribe(outputter)
          executor.subscribe(log_outputter)
          results =
            case options[:subcommand]
            when 'command'
              executor.run_command(targets, options[:object], executor_opts)
            when 'script'
              script_path = find_file(options[:object], executor.future&.fetch('file_paths', false))
              validate_file('script', script_path)
              executor.run_script(targets, script_path, options[:leftovers], executor_opts)
            when 'task'
              pal.run_task(options[:object],
                           targets,
                           options[:task_options],
                           executor,
                           inventory)
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
                src_path = find_file(src, executor.future&.fetch('file_paths', false))
                validate_file('source file', src_path, true)
                executor.upload_file(targets, src_path, dest, executor_opts)
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
      tasks = filter_content(pal.list_tasks_with_cache(filter_content: true), options[:filter])
      outputter.print_tasks(tasks, pal.user_modulepath)
    end

    def show_plan(plan_name)
      outputter.print_plan_info(pal.get_plan_info(plan_name))
    end

    def list_plans
      plans = filter_content(pal.list_plans_with_cache(filter_content: true), options[:filter])
      outputter.print_plans(plans, pal.user_modulepath)
    end

    def list_targets
      if options.keys.any? { |key| TARGETING_OPTIONS.include?(key) }
        target_flag = true
      else
        options[:targets] = 'all'
      end

      outputter.print_targets(
        group_targets_by_source,
        inventory.source,
        config.default_inventoryfile,
        target_flag
      )
    end

    def show_targets
      if options.keys.any? { |key| TARGETING_OPTIONS.include?(key) }
        target_flag = true
      else
        options[:targets] = 'all'
      end

      outputter.print_target_info(
        group_targets_by_source,
        inventory.source,
        config.default_inventoryfile,
        target_flag
      )
    end

    # Returns a hash of targets sorted by those that are found in the
    # inventory and those that are provided on the command line.
    #
    private def group_targets_by_source
      # Retrieve the known group and target names. This needs to be done before
      # updating targets, as that will add adhoc targets to the inventory.
      known_names = inventory.target_names

      update_targets(options)

      inventory_targets, adhoc_targets = options[:targets].partition do |target|
        known_names.include?(target.name)
      end

      { inventory: inventory_targets, adhoc: adhoc_targets }
    end

    def list_groups
      outputter.print_groups(inventory.group_names.sort, inventory.source, config.default_inventoryfile)
    end

    # Looks up a value with Hiera as if in a plan outside an apply block, using
    # provided variable values for interpolations
    #
    def plan_lookup(key, plan_vars: {})
      result = pal.plan_hierarchy_lookup(key, plan_vars: plan_vars)
      outputter.print_plan_lookup(result)
      0
    end

    # Looks up a value with Hiera, using targets as the contexts to perform the
    # look ups in. This should return the same value as a lookup in an apply block.
    #
    def lookup(key, targets, plan_vars: {})
      executor = Bolt::Executor.new(
        config.concurrency,
        analytics,
        options[:noop],
        config.modified_concurrency,
        config.future
      )

      executor.subscribe(outputter) if config.format == 'human'
      executor.subscribe(log_outputter)
      executor.publish_event(type: :plan_start, plan: nil)

      results = outputter.spin do
        pal.lookup(
          key,
          targets,
          inventory,
          executor,
          plan_vars: plan_vars
        )
      end

      executor.shutdown
      outputter.print_result_set(results)

      results.ok ? 0 : 1
    end

    def run_plan(plan_name, plan_arguments, nodes, options)
      unless nodes.empty?
        if plan_arguments['nodes'] || plan_arguments['targets']
          key = plan_arguments.include?('nodes') ? 'nodes' : 'targets'
          raise Bolt::CLIError,
                "A plan's '#{key}' parameter can be specified using the --#{key} option, but in that " \
                "case it must not be specified as a separate #{key}=<value> parameter nor included " \
                "in the JSON data passed in the --params option"
        end

        plan_params = pal.get_plan_info(plan_name)['parameters']
        target_param = plan_params.dig('targets', 'type') =~ /TargetSpec/
        node_param = plan_params.include?('nodes')

        if node_param && target_param
          msg = "Plan parameters include both 'nodes' and 'targets' with type 'TargetSpec', " \
                "neither will populated with the value for --nodes or --targets."
          Bolt::Logger.warn("nodes_targets_parameters", msg)
        elsif node_param
          plan_arguments['nodes'] = nodes.join(',')
        elsif target_param
          plan_arguments['targets'] = nodes.join(',')
        end
      end

      plan_context = { plan_name: plan_name,
                       params: plan_arguments }

      executor = Bolt::Executor.new(config.concurrency,
                                    analytics,
                                    options[:noop],
                                    config.modified_concurrency,
                                    config.future)
      if %w[human rainbow].include?(options.fetch(:format, 'human'))
        executor.subscribe(outputter)
      else
        # Only subscribe to out module events for JSON outputter
        executor.subscribe(outputter, %i[message verbose])
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
        Bolt::Logger.warn("empty_manifest", message)
      end

      executor = Bolt::Executor.new(config.concurrency,
                                    analytics,
                                    noop,
                                    config.modified_concurrency,
                                    config.future)
      executor.subscribe(outputter) if options.fetch(:format, 'human') == 'human'
      executor.subscribe(log_outputter)
      # apply logging looks like plan logging, so tell the outputter we're in a
      # plan even though we're not
      executor.publish_event(type: :plan_start, plan: nil)

      results = nil
      elapsed_time = Benchmark.realtime do
        apply_prep_results = pal.in_plan_compiler(executor, inventory, puppetdb_client) do |compiler|
          compiler.call_function('apply_prep', targets, '_catch_errors' => true)
        end

        apply_results = pal.with_bolt_executor(executor, inventory, puppetdb_client) do
          Puppet.lookup(:apply_executor)
                .apply_ast(ast, apply_prep_results.ok_set.targets, catch_errors: true, noop: noop)
        end

        results = Bolt::ResultSet.new(apply_prep_results.error_set.results + apply_results.results)
      end

      executor.shutdown
      outputter.print_apply_result(results, elapsed_time)
      rerun.update(results)

      results.ok ? 0 : 1
    end

    def list_modules
      outputter.print_module_list(pal.list_modules)
    end

    def show_module(name)
      outputter.print_module_info(**pal.show_module(name))
    end

    def list_plugins
      outputter.print_plugin_list(plugins.list_plugins, pal.user_modulepath)
    end

    def generate_types
      # generate_types will surface a nice error with helpful message if it fails
      pal.generate_types(cache: true)
      0
    end

    # Installs modules declared in the project configuration file.
    #
    def install_project_modules(project, config, force, resolve)
      assert_project_file(project)

      if project.modules.empty? && resolve != false
        outputter.print_message(
          "Project configuration file #{project.project_file} does not "\
          "specify any module dependencies. Nothing to do."
        )
        return 0
      end

      installer = Bolt::ModuleInstaller.new(outputter, pal)

      ok = outputter.spin do
        installer.install(project.modules,
                          project.puppetfile,
                          project.managed_moduledir,
                          config,
                          force: force,
                          resolve: resolve)
      end

      ok ? 0 : 1
    end

    # Adds a single module to the project.
    #
    def add_project_module(name, project, config)
      assert_project_file(project)

      installer = Bolt::ModuleInstaller.new(outputter, pal)

      ok = outputter.spin do
        installer.add(name,
                      project.modules,
                      project.puppetfile,
                      project.managed_moduledir,
                      project.project_file,
                      config)
      end

      ok ? 0 : 1
    end

    # Asserts that there is a project configuration file.
    #
    def assert_project_file(project)
      unless project.project_file?
        command = Bolt::Util.powershell? ? 'New-BoltProject' : 'bolt project init'

        msg = "Could not find project configuration file #{project.project_file}, unable "\
              "to install modules. To create a Bolt project, run '#{command}'."

        raise Bolt::Error.new(msg, 'bolt/missing-project-config-error')
      end
    end

    # Loads a Puppetfile and installs its modules.
    #
    def install_puppetfile(puppetfile_config, puppetfile, moduledir)
      outputter.print_message("Installing modules from Puppetfile")
      installer = Bolt::ModuleInstaller.new(outputter, pal)
      ok = outputter.spin do
        installer.install_puppetfile(puppetfile, moduledir, puppetfile_config)
      end

      ok ? 0 : 1
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
          next if file !~ /\.(yaml|yml)\z/
          # The ".*" here removes any suffix
          topic = File.basename(file, ".*")
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
          guide = Bolt::Util.read_yaml_hash(guides[topic], 'guide')
        rescue SystemCallError => e
          raise Bolt::FileError("#{e.message}: unable to load guide page", filepath)
        end

        # Make sure both topic and guide keys are defined
        unless (%w[topic guide] - guide.keys).empty?
          msg = "Guide file #{guides[topic]} must have a 'topic' key and 'guide' key, but has #{guide.keys} keys."
          raise Bolt::Error.new(msg, 'bolt/invalid-guide')
        end

        outputter.print_guide(**Bolt::Util.symbolize_top_level_keys(guide))
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

    # Returns the path to a file. If the path is an absolute or relative to
    # a file, and the file exists, returns the path as-is. Otherwise, checks if
    # the path is a Puppet file path and looks for the file in a module's files
    # directory.
    #
    def find_file(path, future_file_paths)
      return path if File.exist?(path) || Pathname.new(path).absolute?
      modulepath = Bolt::Config::Modulepath.new(config.modulepath)
      modules    = Bolt::Module.discover(modulepath.full_modulepath, config.project)
      mod, file = path.split(File::SEPARATOR, 2)

      if modules[mod]
        @logger.debug("Did not find file at #{File.expand_path(path)}, checking in module '#{mod}'")
        found = Bolt::Util.find_file_in_module(modules[mod].path, file || "", future_file_paths)
        path = found.nil? ? File.join(modules[mod].path, 'files', file) : found
      end
      path
    end

    def rerun
      @rerun ||= Bolt::Rerun.new(config.rerunfile, config.save_rerun)
    end

    def outputter
      @outputter ||= Bolt::Outputter.for_format(config.format,
                                                config.color,
                                                options[:verbose],
                                                config.trace,
                                                config.spinner)
    end

    def log_outputter
      @log_outputter ||= Bolt::Outputter::Logger.new(options[:verbose], config.trace)
    end

    def analytics
      @analytics ||= begin
        client = Bolt::Analytics.build_client(config.analytics)
        client.bundled_content = bundled_content
        client
      end
    end

    def bundled_content
      # If the bundled content directory is empty, Bolt is likely installed as a gem.
      if ENV['BOLT_GEM'].nil? && incomplete_install?
        msg = <<~MSG.chomp
          Bolt might be installed as a gem. To use Bolt reliably and with all of its
          dependencies, uninstall the 'bolt' gem and install Bolt as a package:
          https://puppet.com/docs/bolt/latest/bolt_installing.html

          If you meant to install Bolt as a gem and want to disable this warning,
          set the BOLT_GEM environment variable.
        MSG

        Bolt::Logger.warn("gem_install", msg)
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
      builtin_module_list = %w[aggregate canary puppetdb_fact secure_env_vars puppet_connect]
      (Dir.children(Bolt::Config::Modulepath::MODULES_PATH) - builtin_module_list).empty?
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
