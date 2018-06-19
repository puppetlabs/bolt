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
require 'bolt/util/on_access'

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
      @config = Bolt::Config.new
      @argv = argv
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
      # Set the mode
      options[:mode] = remaining.shift

      if options[:mode] == 'help'
        options[:help] = true
        options[:mode] = remaining.shift
      end

      # Update the parser for the new mode
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

      config.update(options)
      config.validate
      Bolt::Logger.configure(config)

      # This section handles parsing non-flag options which are
      # mode specific rather then part of the config
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

      # After validation, initialize inventory and targets. Errors here are better to catch early.
      unless options[:action] == 'show'
        if options[:query]
          if options[:nodes].any?
            raise Bolt::CLIError, "Only one of '--nodes' or '--query' may be specified"
          end
          nodes = query_puppetdb_nodes(options[:query])
          options[:targets] = inventory.get_targets(nodes)
          options[:nodes] = nodes if options[:mode] == 'plan'
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
      unless COMMANDS.include?(options[:mode])
        raise Bolt::CLIError,
              "Expected subcommand '#{options[:mode]}' to be one of " \
              "#{COMMANDS.keys.join(', ')}"
      end

      if options[:action].nil?
        raise Bolt::CLIError,
              "Expected an action of the form 'bolt #{options[:mode]} <action>'"
      end

      actions = COMMANDS[options[:mode]]
      unless actions.include?(options[:action])
        raise Bolt::CLIError,
              "Expected action '#{options[:action]}' to be one of " \
              "#{actions.join(', ')}"
      end

      if options[:mode] != 'file' && options[:mode] != 'script' &&
         !options[:leftovers].empty?
        raise Bolt::CLIError,
              "Unknown argument(s) #{options[:leftovers].join(', ')}"
      end

      if %w[task plan].include?(options[:mode]) && options[:action] == 'run'
        if options[:object].nil?
          raise Bolt::CLIError, "Must specify a #{options[:mode]} to run"
        end
        # This may mean that we parsed a parameter as the object
        unless options[:object] =~ /\A([a-z][a-z0-9_]*)?(::[a-z][a-z0-9_]*)*\Z/
          raise Bolt::CLIError,
                "Invalid #{options[:mode]} '#{options[:object]}'"
        end
      end

      if options[:mode] != 'plan' && options[:action] != 'show'
        if options[:nodes].empty? && options[:query].nil?
          raise Bolt::CLIError, "Targets must be specified with '--nodes' or '--query'"
        elsif options[:nodes].any? && options[:query]
          raise Bolt::CLIError, "Only one of '--nodes' or '--query' may be specified"
        end
      end

      if options[:noop] && (options[:mode] != 'task' || options[:action] != 'run')
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
      @puppetdb_client = Bolt::Util::OnAccess.new do
        puppetdb_config = Bolt::PuppetDB::Config.new(nil, config.puppetdb)
        Bolt::PuppetDB::Client.from_config(puppetdb_config)
      end
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

      screen = "#{options[:mode]}_#{options[:action]}"
      # submit a different screen for `bolt task show` and `bolt task show foo`
      if options[:action] == 'show' && options[:object]
        screen += '_object'
      end

      @analytics.screen_view(screen,
                             output_format: config[:format],
                             target_nodes: options.fetch(:targets, []).count,
                             inventory_nodes: inventory.node_names.count,
                             inventory_groups: inventory.group_names.count)

      if options[:mode] == 'plan' || options[:mode] == 'task'
        pal = Bolt::PAL.new(config)
      end

      if options[:action] == 'show'
        if options[:mode] == 'task'
          if options[:object]
            outputter.print_task_info(pal.get_task_info(options[:object]))
          else
            outputter.print_table(pal.list_tasks)
            outputter.print_message("\nUse `bolt task show <task-name>` to view "\
                                    "details and parameters for a specific task.")
          end
        elsif options[:mode] == 'plan'
          if options[:object]
            outputter.print_plan_info(pal.get_plan_info(options[:object]))
          else
            outputter.print_table(pal.list_plans)
            outputter.print_message("\nUse `bolt plan show <plan-name>` to view "\
                                    "details and parameters for a specific plan.")
          end
        end
        return 0
      end

      message = 'There may be processes left executing on some nodes.'

      if options[:task_options] && !options[:params_parsed] && pal
        options[:task_options] = pal.parse_params(options[:mode], options[:object], options[:task_options])
      end

      if options[:mode] == 'plan'
        unless options[:nodes].empty?
          if options[:task_options]['nodes']
            raise Bolt::CLIError,
                  "A plan's 'nodes' parameter may be specified using the --nodes option, but in that " \
                  "case it must not be specified as a separate nodes=<value> parameter nor included " \
                  "in the JSON data passed in the --params option"
          end
          options[:task_options]['nodes'] = options[:nodes].join(',')
        end

        params = options[:noop] ? options[:task_options].merge("_noop" => true) : options[:task_options]
        plan_context = { plan_name: options[:object],
                         params: params }
        plan_context[:description] = options[:description] if options[:description]

        executor = Bolt::Executor.new(config, @analytics, options[:noop])
        executor.start_plan(plan_context)
        result = pal.run_plan(options[:object], options[:task_options], executor, inventory, puppetdb_client)

        # If a non-bolt exeception bubbles up the plan won't get finished
        executor.finish_plan(result)
        outputter.print_plan_result(result)
        code = result.ok? ? 0 : 1
      else
        executor = Bolt::Executor.new(config, @analytics, options[:noop])
        targets = options[:targets]

        results = nil
        outputter.print_head

        elapsed_time = Benchmark.realtime do
          executor_opts = {}
          executor_opts['_description'] = options[:description] if options.key?(:description)
          results =
            case options[:mode]
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
      @outputter ||= Bolt::Outputter.for_format(config[:format], config[:color])
    end
  end
end
