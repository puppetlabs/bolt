# frozen_string_literal: true

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
require 'bolt/outputter'
require 'bolt/puppetdb'
require 'bolt/pal'
require 'bolt/target'
require 'bolt/version'

module Bolt
  class CLIExit < StandardError; end
  class CLI
    COMMANDS = { 'command' => %w[run],
                 'script'  => %w[run],
                 'task'    => %w[show run],
                 'plan'    => %w[show run],
                 'file'    => %w[upload] }.freeze

    attr_reader :config, :options

    def initialize(argv)
      Bolt::Logger.initialize_logging
      @logger = Logging.logger[self]
      @argv = argv
      @config = Bolt::Config.default
      @options = {
        nodes: []
      }
    end

    # Only call after @config has been initialized.
    def inventory
      @inventory ||= Bolt::Inventory.from_config(config)
    end
    private :inventory

    def help?(parser, remaining)
      # Set the subcommand
      options[:subcommand] = remaining.shift

      if options[:subcommand] == 'help'
        options[:help] = true
        options[:subcommand] = remaining.shift
      end

      # Update the parser for the new subcommand
      parser.update

      options[:help]
    end
    private :help?

    def parse
      parser = BoltOptionParser.new(options)

      # This part aims to handle both `bolt <mode> --help` and `bolt help <mode>`.
      remaining = handle_parser_errors { parser.permute(@argv) } unless @argv.empty?
      if @argv.empty? || help?(parser, remaining)
        puts parser.help
        raise Bolt::CLIExit
      end

      # This section handles parsing non-flag options which are
      # subcommand specific rather then part of the config
      options[:action] = remaining.shift
      options[:object] = remaining.shift

      task_options, remaining = remaining.partition { |s| s =~ /.+=/ }
      if options[:task_options]
        unless task_options.empty?
          raise Bolt::CLIError,
                "Parameters must be specified through either the --params " \
                "option or param=value pairs, not both"
        end
        options[:params_parsed] = true
      else
        options[:params_parsed] = false
        options[:task_options] = Hash[task_options.map { |a| a.split('=', 2) }]
      end

      options[:leftovers] = remaining

      validate(options)

      @config = if options[:configfile]
                  Bolt::Config.from_file(options[:configfile], options)
                else
                  boltdir = if options[:boltdir]
                              Bolt::Boltdir.new(options[:boltdir])
                            else
                              Bolt::Boltdir.find_boltdir(Dir.pwd)
                            end
                  Bolt::Config.from_boltdir(boltdir, options)
                end

      Bolt::Logger.configure(config.log, config.color)

      # After validation, initialize inventory and targets. Errors here are better to catch early.
      unless options[:action] == 'show'
        if options[:query]
          if options[:nodes].any?
            raise Bolt::CLIError, "Only one of '--nodes' or '--query' may be specified"
          end
          nodes = query_puppetdb_nodes(options[:query])
          options[:targets] = inventory.get_targets(nodes)
          options[:nodes] = nodes if options[:subcommand] == 'plan'
        else
          options[:targets] = inventory.get_targets(options[:nodes])
        end
      end

      options
    rescue Bolt::Error => e
      warn e.message
      raise e
    end

    def validate(options)
      unless COMMANDS.include?(options[:subcommand])
        raise Bolt::CLIError,
              "Expected subcommand '#{options[:subcommand]}' to be one of " \
              "#{COMMANDS.keys.join(', ')}"
      end

      if options[:action].nil?
        raise Bolt::CLIError,
              "Expected an action of the form 'bolt #{options[:subcommand]} <action>'"
      end

      actions = COMMANDS[options[:subcommand]]
      unless actions.include?(options[:action])
        raise Bolt::CLIError,
              "Expected action '#{options[:action]}' to be one of " \
              "#{actions.join(', ')}"
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

      if options[:subcommand] != 'plan' && options[:action] != 'show'
        if options[:nodes].empty? && options[:query].nil?
          raise Bolt::CLIError, "Targets must be specified with '--nodes' or '--query'"
        elsif options[:nodes].any? && options[:query]
          raise Bolt::CLIError, "Only one of '--nodes' or '--query' may be specified"
        end
      end

      if options[:boltdir] && options[:configfile]
        raise Bolt::CLIError, "Only one of '--boltdir' or '--configfile' may be specified"
      end

      if options[:noop] && (options[:subcommand] != 'task' || options[:action] != 'run')
        raise Bolt::CLIError,
              "Option '--noop' may only be specified when running a task"
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
      return @puppetdb_client if @puppetdb_client
      puppetdb_config = Bolt::PuppetDB::Config.load_config(nil, config.puppetdb)
      @puppetdb_client = Bolt::PuppetDB::Client.new(puppetdb_config)
    end

    def query_puppetdb_nodes(query)
      puppetdb_client.query_certnames(query)
    end

    def execute(options)
      message = nil

      handler = Signal.trap :INT do |signo|
        @logger.info(
          "Exiting after receiving SIG#{Signal.signame(signo)} signal.#{message ? ' ' + message : ''}"
        )
        exit!
      end

      @analytics = Bolt::Analytics.build_client

      screen = "#{options[:subcommand]}_#{options[:action]}"
      # submit a different screen for `bolt task show` and `bolt task show foo`
      if options[:action] == 'show' && options[:object]
        screen += '_object'
      end

      @analytics.screen_view(screen,
                             output_format: config.format,
                             target_nodes: options.fetch(:targets, []).count,
                             inventory_nodes: inventory.node_names.count,
                             inventory_groups: inventory.group_names.count)

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
        end
        return 0
      end

      message = 'There may be processes left executing on some nodes.'

      if %w[task plan].include?(options[:subcommand]) && options[:task_options] && !options[:params_parsed] && pal
        options[:task_options] = pal.parse_params(options[:subcommand], options[:object], options[:task_options])
      end

      if options[:subcommand] == 'plan'
        code = run_plan(options[:object], options[:task_options], options[:nodes], options)
      else
        executor = Bolt::Executor.new(config.concurrency, @analytics, options[:noop], bundled_content: bundled_content)
        targets = options[:targets]

        results = nil
        outputter.print_head

        elapsed_time = Benchmark.realtime do
          executor_opts = {}
          executor_opts['_description'] = options[:description] if options.key?(:description)
          results =
            case options[:subcommand]
            when 'command'
              executor.run_command(targets, options[:object], executor_opts) do |event|
                outputter.print_event(event)
              end
            when 'script'
              script = options[:object]
              validate_file('script', script)
              executor.run_script(
                targets, script, options[:leftovers], executor_opts
              ) do |event|
                outputter.print_event(event)
              end
            when 'task'
              pal.run_task(options[:object],
                           targets,
                           options[:task_options],
                           executor,
                           inventory,
                           options[:description]) do |event|
                outputter.print_event(event)
              end
            when 'file'
              src = options[:object]
              dest = options[:leftovers].first

              if dest.nil?
                raise Bolt::CLIError, "A destination path must be specified"
              end
              validate_file('source file', src)
              executor.file_upload(targets, src, dest, executor_opts) do |event|
                outputter.print_event(event)
              end
            end
        end

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
      @analytics&.finish
    end

    def show_task(task_name)
      outputter.print_task_info(pal.get_task_info(task_name))
    end

    def list_tasks
      outputter.print_table(pal.list_tasks)
      outputter.print_message("\nUse `bolt task show <task-name>` to view "\
                              "details and parameters for a specific task.")
    end

    def show_plan(plan_name)
      outputter.print_plan_info(pal.get_plan_info(plan_name))
    end

    def list_plans
      outputter.print_table(pal.list_plans)
      outputter.print_message("\nUse `bolt plan show <plan-name>` to view "\
                              "details and parameters for a specific plan.")
    end

    def run_plan(plan_name, plan_arguments, nodes, options)
      unless nodes.empty?
        if plan_arguments['nodes']
          raise Bolt::CLIError,
                "A plan's 'nodes' parameter may be specified using the --nodes option, but in that " \
                "case it must not be specified as a separate nodes=<value> parameter nor included " \
                "in the JSON data passed in the --params option"
        end
        plan_arguments['nodes'] = nodes.join(',')
      end

      params = options[:noop] ? plan_arguments.merge('_noop' => true) : plan_arguments
      plan_context = { plan_name: plan_name,
                       params: params }
      plan_context[:description] = options[:description] if options[:description]

      executor = Bolt::Executor.new(config.concurrency, @analytics, options[:noop], bundled_content: bundled_content)
      executor.start_plan(plan_context)
      result = pal.run_plan(plan_name, plan_arguments, executor, inventory, puppetdb_client)

      # If a non-bolt exeception bubbles up the plan won't get finished
      executor.finish_plan(result)
      outputter.print_plan_result(result)
      result.ok? ? 0 : 1
    end

    def pal
      @pal ||= Bolt::PAL.new(config.modulepath, config.hiera_config, config.compile_concurrency)
    end

    def validate_file(type, path)
      if path.nil?
        raise Bolt::CLIError, "A #{type} must be specified"
      end

      stat = file_stat(path)

      if !stat.readable?
        raise Bolt::FileError.new("The #{type} '#{path}' is unreadable", path)
      elsif !stat.file?
        raise Bolt::FileError.new("The #{type} '#{path}' is not a file", path)
      end
    rescue Errno::ENOENT
      raise Bolt::FileError.new("The #{type} '#{path}' does not exist", path)
    end

    def file_stat(path)
      File.stat(path)
    end

    def outputter
      @outputter ||= Bolt::Outputter.for_format(config.format, config.color, config.trace)
    end

    def bundled_content
      if %w[plan task].include?(options[:subcommand])
        default_content = Bolt::PAL.new([], nil)
        plans = default_content.list_plans.each_with_object([]) do |iter, col|
          col << iter&.first
        end
        tasks = default_content.list_tasks.each_with_object([]) do |iter, col|
          col << iter&.first
        end
        plans.concat tasks
      end
    end
  end
end
