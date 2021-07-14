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
require 'bolt/application'
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
require 'bolt/target'
require 'bolt/version'

module Bolt
  class CLIExit < StandardError; end

  class CLI
    attr_reader :outputter, :rerun

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

    SUCCESS = 0
    ERROR   = 1
    FAILURE = 2

    def initialize(argv)
      Bolt::Logger.initialize_logging
      @logger = Bolt::Logger.logger(self)
      @argv   = argv
    end

    # TODO: Move this to the parser.
    #
    # Query whether the help text needs to be displayed.
    #
    # @param remaining [Array] Remaining arguments after parsing the command.
    # @param options [Hash] The CLI options.
    #
    private def help?(options, remaining)
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

    # TODO: Move most of this to the parser.
    #
    # Parse the command and validate options. All errors that are raised here
    # are not handled by the outputter, as it relies on config being loaded.
    #
    def parse
      with_error_handling do
        options = {}
        parser  = BoltOptionParser.new(options)

        # This part aims to handle both `bolt <mode> --help` and `bolt help <mode>`.
        remaining = parser.permute(@argv) unless @argv.empty?

        if @argv.empty? || help?(options, remaining)
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

        if options[:version]
          puts Bolt::VERSION
          raise Bolt::CLIExit
        end

        options[:object] = remaining.shift

        # Handle reading a command from a file
        if options[:subcommand] == 'command' && options[:object]
          options[:object] = Bolt::Util.get_arg_input(options[:object])
        end

        # Only parse params for task or plan
        if %w[task plan].include?(options[:subcommand])
          params, remaining = remaining.partition { |s| s =~ /.+=/ }
          if options[:params]
            unless params.empty?
              raise Bolt::CLIError,
                    "Parameters must be specified through either the --params " \
                    "option or param=value pairs, not both"
            end
            options[:params_parsed] = true
          elsif params.any?
            options[:params_parsed] = false
            options[:params] = Hash[params.map { |a| a.split('=', 2) }]
          else
            options[:params_parsed] = true
            options[:params] = {}
          end
        end
        options[:leftovers] = remaining

        # Default to verbose for everything except plans
        unless options.key?(:verbose)
          options[:verbose] = options[:subcommand] != 'plan'
        end

        validate(options)
        validate_ps_version

        options
      end
    end

    # TODO: Move this to the parser.
    #
    # Print a welcome message when users first install Bolt and run `bolt`,
    # `bolt help` or `bolt --help`.
    #
    private def welcome_message
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

    # TODO: Move this to the parser.
    #
    # Validate the command. Ensure that the subcommand and action are
    # recognized, all required arguments are specified, and only supported
    # command-line options are used.
    #
    # @param options [Hash] The CLI options.
    #
    private def validate(options)
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

      if options[:action] == 'convert' && !options[:object]
        raise Bolt::CLIError, "Must specify a plan."
      end

      if options[:subcommand] == 'module' && options[:action] == 'install' && options[:object]
        command = Bolt::Util.powershell? ? 'Add-BoltModule -Module' : 'bolt module add'
        raise Bolt::CLIError, "Invalid argument '#{options[:object]}'. To add a new module to "\
                              "the project, run '#{command} #{options[:object]}'."
      end

      if %w[download upload].include?(options[:action])
        raise Bolt::CLIError, "Must specify a source" unless options[:object]

        if options[:leftovers].empty?
          raise Bolt::CLIError, "Must specify a destination"
        elsif options[:leftovers].size > 1
          raise Bolt::CLIError, "Unknown arguments #{options[:leftovers].drop(1).join(', ')}"
        end
      end

      if options[:subcommand] == 'group' && options[:object]
        raise Bolt::CLIError, "Unknown argument #{options[:object]}"
      end

      if options[:action] == 'generate-types' && options[:object]
        raise Bolt::CLIError, "Unknown argument #{options[:object]}"
      end

      if options[:subcommand] == 'module' && options[:action] == 'show' && options[:object]
        raise Bolt::CLIError, "Unknown argument #{options[:object]}"
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

      validate_targeting_options(options)
    end

    # Validates that only one targeting option is provided and that commands
    # requiring a targeting option received one.
    #
    # @param options [Hash] The CLI options.
    #
    private def validate_targeting_options(options)
      target_opts   = options.slice(*TARGETING_OPTIONS)
      target_string = "'--targets', '--rerun', or '--query'"

      if target_opts.length > 1
        raise Bolt::CLIError, "Only one targeting option can be specified: #{target_string}"
      end

      return if %w[guide module plan project secret].include?(options[:subcommand]) ||
                %w[convert new show].include?(options[:action]) ||
                options[:plan_hierarchy]

      if target_opts.empty?
        raise Bolt::CLIError, "Command requires a targeting option: #{target_string}"
      end
    end

    # Execute a Bolt command. The +options+ hash includes the subcommand and
    # action to be run, as well as any additional arguments and options for the
    # command.
    #
    # @param options [Hash] The CLI options.
    #
    def execute(options)
      with_signal_handling do
        with_error_handling do
          # TODO: Separate from options hash and pass as own args.
          command = options[:subcommand]
          action  = options[:action]

          #
          # INITIALIZE CORE CLASSES
          #

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

          config = Bolt::Config.from_project(project, options)

          @outputter = Bolt::Outputter.for_format(
            config.format,
            config.color,
            options[:verbose],
            config.trace,
            config.spinner
          )

          @rerun = Bolt::Rerun.new(config.rerunfile, config.save_rerun)

          # TODO: Subscribe this to the executor.
          analytics = begin
            client = Bolt::Analytics.build_client(config.analytics)
            client.bundled_content = bundled_content(options)
            client
          end

          # TODO: Configure logger with a separate method call?
          Bolt::Logger.configure(config.log, config.color, config.disable_warnings)
          Bolt::Logger.stream = config.stream
          Bolt::Logger.analytics = analytics
          Bolt::Logger.flush_queue

          executor = Bolt::Executor.new(
            config.concurrency,
            analytics,
            options[:noop],
            config.modified_concurrency,
            config.future
          )

          pal = Bolt::PAL.new(
            Bolt::Config::Modulepath.new(config.modulepath),
            config.hiera_config,
            config.project.resource_types,
            config.compile_concurrency,
            config.trusted_external,
            config.apply_settings,
            config.project
          )

          plugins = Bolt::Plugin.setup(config, pal, analytics)

          inventory = Bolt::Inventory.from_config(config, plugins)

          log_outputter = Bolt::Outputter::Logger.new(options[:verbose], config.trace)

          #
          # FINALIZING SETUP
          #

          check_gem_install
          warn_inventory_overrides_cli(config, options)
          submit_screen_view(analytics, config, inventory, options)
          process_target_list(plugins.puppetdb_client, @rerun, options)

          # TODO: Fix casing issue in Windows.
          config.check_path_case('modulepath', config.modulepath)

          if options[:clear_cache] && File.exist?(config.project.plugin_cache_file)
            FileUtils.rm(config.project.plugin_cache_file)
          end

          # TODO: Include logic for handling special cases when subscribing the
          #       outputter (e.g. `plan run` and `apply`).
          case command
          when 'apply', 'lookup'
            if %w[human rainbow].include?(config.format)
              executor.subscribe(outputter)
            end
          when 'plan'
            if %w[human rainbow].include?(config.format)
              executor.subscribe(outputter)
            else
              executor.subscribe(outputter, %i[message verbose])
            end
          else
            executor.subscribe(outputter)
          end

          executor.subscribe(log_outputter)

          # TODO: Figure out where this should really go. It doesn't seem to
          #       make sense in the application, since the params should already
          #       be data when they reach that point.
          if %w[plan task].include?(command) && action == 'run'
            options[:params] = parse_params(
              command,
              options[:object],
              pal,
              **options.slice(:params, :params_parsed)
            )
          end

          if command == 'script'
            options[:arguments] = options[:leftovers]
          end

          application = Bolt::Application.new(
            analytics: analytics,
            config:    config,
            executor:  executor,
            inventory: inventory,
            pal:       pal,
            plugins:   plugins
          )

          process_command(application, command, action, options)
        ensure
          analytics&.finish
        end
      end
    end

    # Process the command.
    #
    # @param app [Bolt::Application] The application.
    # @param command [String] The command.
    # @param action [String, NilClass] The action.
    # @param options [Hash] The CLI options.
    #
    private def process_command(app, command, action, options)
      case command
      when 'apply'
        results = outputter.spin do
          app.apply(options[:object], options[:targets], **options.slice(:code, :noop))
        end
        rerun.update(results)
        app.shutdown
        outputter.print_apply_result(results)
        results.ok? ? SUCCESS : FAILURE

      when 'command'
        outputter.print_head
        results = outputter.spin do
          app.command_run(options[:object], options[:targets], **options.slice(:env_vars))
        end
        rerun.update(results)
        app.shutdown
        outputter.print_summary(results, results.elapsed_time)
        results.ok? ? SUCCESS : FAILURE

      when 'file'
        case action
        when 'download'
          outputter.print_head
          results = outputter.spin do
            app.file_download(options[:object], options[:leftovers].first, options[:targets])
          end
          rerun.update(results)
          app.shutdown
          outputter.print_summary(results, results.elapsed_time)
          results.ok? ? SUCCESS : FAILURE
        when 'upload'
          outputter.print_head
          results = outputter.spin do
            app.file_upload(options[:object], options[:leftovers].first, options[:targets])
          end
          rerun.update(results)
          app.shutdown
          outputter.print_summary(results, results.elapsed_time)
          results.ok? ? SUCCESS : FAILURE
        end

      when 'group'
        outputter.print_groups(**app.group_show)
        SUCCESS

      when 'guide'
        if options[:object]
          outputter.print_guide(**app.guide(options[:object]))
        else
          outputter.print_topics(**app.guide)
        end
        SUCCESS

      when 'inventory'
        targets = app.inventory_show(options[:targets])
                     .merge(flag: !options[:targets].nil?)
        if options[:detail]
          outputter.print_target_info(**targets)
        else
          outputter.print_targets(**targets)
        end
        SUCCESS

      when 'lookup'
        options[:vars] = parse_vars(options[:leftovers])
        if options[:plan_hierarchy]
          outputter.print_plan_lookup(app.plan_lookup(options[:object], **options.slice(:vars)))
          SUCCESS
        else
          results = outputter.spin do
            app.lookup(options[:object], options[:targets], **options.slice(:vars))
          end
          rerun.update(results)
          app.shutdown
          outputter.print_result_set(results)
          results.ok? ? SUCCESS : FAILURE
        end

      when 'module'
        case action
        when 'add'
          ok = outputter.spin { app.module_add(options[:object], outputter) }
          ok ? SUCCESS : FAILURE
        when 'generate-types'
          app.module_generate_types
          SUCCESS
        when 'install'
          ok = outputter.spin { app.module_install(outputter, **options.slice(:force, :resolve)) }
          ok ? SUCCESS : FAILURE
        when 'show'
          outputter.print_module_list(app.module_show)
          SUCCESS
        end

      when 'plan'
        case action
        when 'convert'
          app.plan_convert(options[:object])
          SUCCESS
        when 'new'
          result = app.plan_new(options[:object], **options.slice(:puppet))
          outputter.print_new_plan(**result)
          SUCCESS
        when 'run'
          result = app.plan_run(options[:object], options[:targets], **options.slice(:params))
          rerun.update(result)
          app.shutdown
          outputter.print_plan_result(result)
          result.ok? ? SUCCESS : FAILURE
        when 'show'
          if options[:object]
            outputter.print_plan_info(**app.show_plan(options[:object]))
          else
            outputter.print_plans(**app.list_plans(**options.slice(:filter)))
          end
          SUCCESS
        end

      when 'plugin'
        outputter.print_plugin_list(**app.plugin_show)
        SUCCESS

      when 'project'
        case action
        when 'init'
          app.project_init(options[:object], outputter, **options.slice(:modules))
          SUCCESS
        when 'migrate'
          app.project_migrate(outputter)
          SUCCESS
        end

      when 'script'
        outputter.print_head
        results = outputter.spin do
          app.script_run(options[:object], options[:targets], **options.slice(:arguments, :env_vars))
        end
        rerun.update(results)
        app.shutdown
        outputter.print_summary(results, results.elapsed_time)
        results.ok? ? SUCCESS : FAILURE

      when 'secret'
        case action
        when 'createkeys'
          result = app.secret_createkeys(**options.slice(:force, :plugin))
          outputter.print_message(result)
          SUCCESS
        when 'decrypt'
          result = app.secret_decrypt(options[:object], **options.slice(:plugin))
          outputter.print_message(result)
          SUCCESS
        when 'encrypt'
          result = app.secret_encrypt(options[:object], **options.slice(:plugin))
          outputter.print_message(result)
          SUCCESS
        end

      when 'task'
        case action
        when 'run'
          outputter.print_head
          results = outputter.spin do
            app.task_run(options[:object], options[:targets], **options.slice(:params))
          end
          rerun.update(results)
          app.shutdown
          outputter.print_summary(results, results.elapsed_time)
          results.ok? ? SUCCESS : FAILURE
        when 'show'
          if options[:object]
            outputter.print_task_info(**app.show_task(options[:object]))
          else
            outputter.print_tasks(**app.list_tasks(**options.slice(:filter)))
          end
          SUCCESS
        end
      end
    end

    # Process the target list by turning a PuppetDB query or rerun mode into a
    # list of target names.
    #
    # @param pdb_client [Bolt::PuppetDB::Client] The PuppetDB client.
    # @param rerun [Bolt::Rerun] The Rerun instance.
    # @param options [Hash] The CLI options.
    #
    private def process_target_list(pdb_client, rerun, options)
      return if options[:targets]

      options[:targets] = if options[:query]
                            pdb_client.query_certnames(options[:query])
                          elsif options[:rerun]
                            rerun.get_targets(options[:rerun])
                          end
    end

    # TODO: Discuss whether we still want / need to collect analytics for
    #       bundled content.
    #
    # List content that ships with Bolt.
    #
    # @param options [Hash] The CLI options.
    #
    private def bundled_content(options)
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

    # Check and warn if Bolt is installed as a gem.
    #
    private def check_gem_install
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
    end

    # Print a fatal error. Print using the outputter if it's configured.
    # Otherwise, mock the output by printing directly to stdout.
    #
    # @param error [StandardError] The error to print.
    #
    private def fatal_error(error)
      if @outputter
        @outputter.fatal_error(error)
      elsif $stdout.isatty
        $stdout.puts("\033[31m#{error.message}\033[0m")
      else
        $stdout.puts(error.message)
      end
    end

    # Query whether Bolt is installed as a gem or package by checking if all
    # built-in modules are installed.
    #
    private def incomplete_install?
      builtin_module_list = %w[aggregate canary puppetdb_fact secure_env_vars puppet_connect]
      (Dir.children(Bolt::Config::Modulepath::MODULES_PATH) - builtin_module_list).empty?
    end

    # Parse parameters for tasks and plans.
    #
    # @param options [Hash] Options from the calling method.
    #
    private def parse_params(command, object, pal, params: nil, params_parsed: nil)
      if params
        params_parsed ? params : pal.parse_params(command, object, params)
      else
        {}
      end
    end

    # Parse variables for lookups.
    #
    # @param vars [Array, NilClass] Unparsed variables.
    #
    private def parse_vars(vars)
      return unless vars
      Hash[vars.map { |a| a.split('=', 2) }]
    end

    # TODO: See if this can be moved to Bolt::Analytics.
    #
    # Submit a screen view to the analytics client.
    #
    # @param analytics [Bolt::Analytics] The analytics client.
    # @param config [Bolt::Config] The config.
    # @param inventory [Bolt::Inventory] The inventory.
    # @param options [Hash] The CLI options.
    #
    private def submit_screen_view(analytics, config, inventory, options)
      screen = "#{options[:subcommand]}_#{options[:action]}"

      if options[:action] == 'show' && options[:object]
        screen += '_object'
      end

      pp_count, yaml_count = if File.exist?(config.project.plans_path)
                               %w[pp yaml].map do |extension|
                                 Find.find(config.project.plans_path.to_s)
                                     .grep(/.*\.#{extension}/)
                                     .length
                               end
                             else
                               [0, 0]
                             end

      screen_view_fields = {
        output_format:     config.format,
        boltdir_type:      config.project.type,
        puppet_plan_count: pp_count,
        yaml_plan_count:   yaml_count
      }

      if options.key?(:targets)
        screen_view_fields.merge!(
          target_nodes:      options[:targets].count,
          inventory_nodes:   inventory.node_names.count,
          inventory_groups:  inventory.group_names.count,
          inventory_version: inventory.version
        )
      end

      analytics.screen_view(screen, **screen_view_fields)
    end

    # Issue a deprecation warning if the user is running an unsupported version
    # of PowerShell on the controller.
    #
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

    # Warn the user that transport configuration options set from the command
    # line may be overridden by transport configuration set in the inventory.
    #
    # @param opts [Hash] The CLI options.
    #
    private def warn_inventory_overrides_cli(config, opts)
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

    # Handle and print errors.
    #
    private def with_error_handling
      yield
    rescue Bolt::Error => e
      fatal_error(e)
      raise e
    end

    # Handle signals.
    #
    private def with_signal_handling
      handler = Signal.trap :INT do |signo|
        Bolt::Logger.logger(self).info(
          "Exiting after receiving SIG#{Signal.signame(signo)} signal. "\
          "There might be processes left executing on some targets."
        )
        exit!
      end

      yield
    ensure
      Signal.trap :INT, handler if handler
    end
  end
end
