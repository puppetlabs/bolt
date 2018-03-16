# frozen_string_literal: true

require 'uri'
require 'benchmark'
require 'json'
require 'io/console'
require 'logging'
require 'optparse'
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
  class CLIError < Bolt::Error
    def initialize(msg)
      super(msg, "bolt/cli-error")
    end
  end

  class CLIExit < StandardError; end

  class CLI
    class BoltOptionParser < OptionParser
      BANNER = <<-HELP
Usage: bolt <subcommand> <action> [options]

Available subcommands:
    bolt command run <command>       Run a command remotely
    bolt script run <script>         Upload a local script and run it remotely
    bolt task show                   Show list of available tasks
    bolt task show <task>            Show documentation for task
    bolt task run <task> [params]    Run a Puppet task
    bolt plan show                   Show list of available plans
    bolt plan show <plan>            Show details for plan
    bolt plan run <plan> [params]    Run a Puppet task plan
    bolt file upload <src> <dest>    Upload a local file

where [options] are:
      HELP

      TASK_HELP = <<-HELP
Usage: bolt task <action> <task> [options] [parameters]

Available actions are:
    show                             Show list of available tasks
    show <task>                      Show documentation for task
    run                              Run a Puppet task

Parameters are of the form <parameter>=<value>.

Available options are:
      HELP

      COMMAND_HELP = <<-HELP
Usage: bolt command <action> <command> [options]

Available actions are:
    run                              Run a command remotely

Available options are:
      HELP

      SCRIPT_HELP = <<-HELP
Usage: bolt script <action> <script> [[arg1] ... [argN]] [options]

Available actions are:
    run                              Upload a local script and run it remotely

Available options are:
      HELP

      PLAN_HELP = <<-HELP
Usage: bolt plan <action> <plan> [options] [parameters]

Available actions are:
    show                             Show list of available plans
    show <plan>                      Show details for plan
    run                              Run a Puppet task plan

Parameters are of the form <parameter>=<value>.

Available options are:
      HELP

      FILE_HELP = <<-HELP
Usage: bolt file <action> [options]

Available actions are:
    upload <src> <dest>              Upload local file <src> to <dest> on each node

Available options are:
      HELP

      # A helper mixin for OptionParser::Switch instances which will allow
      # us to show/hide particular switch in the help message produced by
      # the OptionParser#help method on demand.
      module SwitchHider
        attr_accessor :hide

        def summarize(*args)
          return self if hide
          super
        end
      end

      def initialize(options)
        super()

        @options = options

        @nodes = define('-n', '--nodes NODES',
                        'Node(s) to connect to in URI format [protocol://]host[:port] (Optional)',
                        'Eg. --nodes bolt.puppet.com',
                        'Eg. --nodes localhost,ssh://nix.com:2222,winrm://windows.puppet.com',
                        # An empty line in a switch description causes the OptionParser#help
                        # method to raise an exception. Specifying a line containing only a
                        # newline is the closest one can get to the empty line without
                        # triggering that exception.
                        "\n",
                        '* NODES can either be comma-separated, \'@<file>\' to read',
                        '* nodes from a file, or \'-\' to read from stdin',
                        '* Windows nodes must specify protocol with winrm://',
                        '* protocol is `ssh` by default, may be `ssh` or `winrm`',
                        '* port defaults to `22` for SSH',
                        '* port defaults to `5985` or `5986` for WinRM, based on the --[no-]ssl setting') do |nodes|
          @options[:nodes] << get_arg_input(nodes)
        end.extend(SwitchHider)
        @query = define('-q', '--query QUERY',
                        'Query PuppetDB to determine the targets') do |query|
          @options[:query] = query
        end.extend(SwitchHider)
        define('-u', '--user USER',
               'User to authenticate as (Optional)') do |user|
          @options[:user] = user
        end
        define('-p', '--password [PASSWORD]',
               'Password to authenticate with (Optional).',
               'Omit the value to prompt for the password.') do |password|
          if password.nil?
            STDOUT.print "Please enter your password: "
            @options[:password] = STDIN.noecho(&:gets).chomp
            STDOUT.puts
          else
            @options[:password] = password
          end
        end
        define('--private-key KEY',
               'Private ssh key to authenticate with (Optional)') do |key|
          @options[:'private-key'] = key
        end
        define('--tmpdir DIR',
               'The directory to upload and execute temporary files on the target (Optional)') do |tmpdir|
          @options[:tmpdir] = tmpdir
        end
        define('-c', '--concurrency CONCURRENCY', Integer,
               'Maximum number of simultaneous connections ' \
               '(Optional, defaults to 100)') do |concurrency|
          @options[:concurrency] = concurrency
        end
        define('--connect-timeout TIMEOUT', Integer,
               'Connection timeout (Optional)') do |timeout|
          @options[:'connect-timeout'] = timeout
        end
        define('--modulepath MODULES',
               'List of directories containing modules, ' \
               "separated by #{File::PATH_SEPARATOR}") do |modulepath|
          @options[:modulepath] = modulepath.split(File::PATH_SEPARATOR)
        end
        define('--params PARAMETERS',
               'Parameters to a task or plan') do |params|
          @options[:task_options] = parse_params(params)
        end

        define('--format FORMAT',
               'Output format to use: human or json') do |format|
          @options[:format] = format
        end
        define('--[no-]host-key-check',
               'Check host keys with SSH') do |host_key_check|
          @options[:'host-key-check'] = host_key_check
        end
        define('--[no-]ssl',
               'Use SSL with WinRM') do |ssl|
          @options[:ssl] = ssl
        end
        define('--[no-]ssl-verify',
               'Verify remote host SSL certificate with WinRM') do |ssl_verify|
          @options[:'ssl-verify'] = ssl_verify
        end
        define('--transport TRANSPORT', TRANSPORTS.keys.map(&:to_s),
               "Specify a default transport: #{TRANSPORTS.keys.join(', ')}") do |t|
          @options[:transport] = t
        end
        define('--run-as USER',
               'User to run as using privilege escalation') do |user|
          @options[:'run-as'] = user
        end
        define('--sudo-password [PASSWORD]',
               'Password for privilege escalation') do |password|
          if password.nil?
            STDOUT.print "Please enter your privilege escalation password: "
            @options[:'sudo-password'] = STDIN.noecho(&:gets).chomp
            STDOUT.puts
          else
            @options[:'sudo-password'] = password
          end
        end
        define('--configfile CONFIG_PATH',
               'Specify where to load the config file from') do |path|
          @options[:configfile] = path
        end
        define('--inventoryfile INVENTORY_PATH',
               'Specify where to load the inventory file from') do |path|
          if ENV.include?(Bolt::Inventory::ENVIRONMENT_VAR)
            raise Bolt::CLIError, "Cannot pass inventory file when #{Bolt::Inventory::ENVIRONMENT_VAR} is set"
          end
          @options[:inventoryfile] = path
        end
        define_tail('--[no-]tty',
                    'Request a pseudo TTY on nodes that support it') do |tty|
          @options[:tty] = tty
        end
        define_tail('--noop',
                    'Execute a task that supports it in noop mode') do |_|
          @options[:noop] = true
        end
        define_tail('-h', '--help', 'Display help') do |_|
          @options[:help] = true
        end
        define_tail('--verbose', 'Display verbose logging') do |_|
          @options[:verbose] = true
        end
        define_tail('--debug', 'Display debug logging') do |_|
          @options[:debug] = true
        end
        define_tail('--version', 'Display the version') do |_|
          puts Bolt::VERSION
          raise Bolt::CLIExit
        end

        update
      end

      def update
        # show the --nodes and --query switches by default
        @nodes.hide = @query.hide = false

        # Update the banner according to the mode
        self.banner = case @options[:mode]
                      when 'plan'
                        # don't show the --nodes and --query switches in the plan help
                        @nodes.hide = @query.hide = true
                        PLAN_HELP
                      when 'command'
                        COMMAND_HELP
                      when 'script'
                        SCRIPT_HELP
                      when 'task'
                        TASK_HELP
                      when 'file'
                        FILE_HELP
                      else
                        BANNER
                      end
      end

      def parse_params(params)
        json = get_arg_input(params)
        JSON.parse(json)
      rescue JSON::ParserError => err
        raise Bolt::CLIError, "Unable to parse --params value as JSON: #{err}"
      end

      def get_arg_input(value)
        if value.start_with?('@')
          file = value.sub(/^@/, '')
          read_arg_file(file)
        elsif value == '-'
          STDIN.read
        else
          value
        end
      end

      def read_arg_file(file)
        File.read(file)
      rescue StandardError => err
        raise Bolt::CLIError, "Error attempting to read #{file}: #{err}"
      end
    end

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

      config.load_file(options[:configfile])
      config.update_from_cli(options)
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
      else
        options[:task_options] = Hash[task_options.map { |a| a.split('=', 2) }]
      end

      options[:leftovers] = remaining

      validate(options)

      # After validation, initialize inventory and targets. Errors here are better to catch early.
      unless options[:action] == 'show' || options[:mode] == 'plan'
        if options[:query]
          nodes = query_puppetdb_nodes(options[:query])
          options[:targets] = inventory.get_targets(nodes)
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
      puppetdb_config = Bolt::PuppetDB::Config.new(nil, config.puppetdb)
      @puppetdb_client = Bolt::PuppetDB::Client.from_config(puppetdb_config)
    end

    def query_puppetdb_nodes(query)
      puppetdb_client.query_certnames(query)
    rescue StandardError => e
      raise Bolt::CLIError, "Could not retrieve targets from PuppetDB: #{e}"
    end

    def execute(options)
      message = nil

      handler = Signal.trap :INT do |signo|
        @logger.info(
          "Exiting after receiving SIG#{Signal.signame(signo)} signal.#{message ? ' ' + message : ''}"
        )
        exit!
      end

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
        executor = Bolt::Executor.new(config, options[:noop], true)
        result = pal.run_plan(options[:object], options[:task_options], executor, inventory)
        outputter.print_plan_result(result)
        # An exception would have been raised if the plan failed
        code = 0
      else
        executor = Bolt::Executor.new(config, options[:noop])
        targets = options[:targets]

        results = nil
        outputter.print_head

        elapsed_time = Benchmark.realtime do
          results =
            case options[:mode]
            when 'command'
              executor.run_command(targets, options[:object]) do |event|
                outputter.print_event(event)
              end
            when 'script'
              script = options[:object]
              validate_file('script', script)
              executor.run_script(
                targets, script, options[:leftovers]
              ) do |event|
                outputter.print_event(event)
              end
            when 'task'
              pal.run_task(options[:object],
                           targets,
                           options[:task_options],
                           executor,
                           inventory) do |event|
                outputter.print_event(event)
              end
            when 'file'
              src = options[:object]
              dest = options[:leftovers].first

              if dest.nil?
                raise Bolt::CLIError, "A destination path must be specified"
              end
              validate_file('source file', src)
              executor.file_upload(targets, src, dest) do |event|
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
    end

    def validate_file(type, path)
      if path.nil?
        raise Bolt::CLIError, "A #{type} must be specified"
      end

      stat = file_stat(path)

      if !stat.readable?
        raise Bolt::CLIError, "The #{type} '#{path}' is unreadable"
      elsif !stat.file?
        raise Bolt::CLIError, "The #{type} '#{path}' is not a file"
      end
    rescue Errno::ENOENT
      raise Bolt::CLIError, "The #{type} '#{path}' does not exist"
    end

    def file_stat(path)
      File.stat(path)
    end

    def outputter
      @outputter ||= Bolt::Outputter.for_format(config[:format])
    end
  end
end
