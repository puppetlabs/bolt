require 'uri'
require 'optparse'
require 'benchmark'
require 'logger'
require 'json'
require 'bolt/node'
require 'bolt/version'
require 'bolt/error'
require 'bolt/executor'
require 'bolt/outputter'
require 'bolt/config'
require 'io/console'

module Bolt
  class CLIError < Bolt::Error
    attr_reader :error_code

    def initialize(msg, error_code: 1)
      super(msg, "bolt/cli-error")
      @error_code = error_code
    end
  end

  class CLIExit < StandardError; end

  class CLI
    BANNER = <<-HELP.freeze
Usage: bolt <subcommand> <action> [options]

Available subcommands:
    bolt command run <command>       Run a command remotely
    bolt script run <script>         Upload a local script and run it remotely
    bolt task show                   Show list of available tasks
    bolt task show <task>            Show documentation for task
    bolt task run <task> [params]    Run a Puppet task
    bolt plan show                   Show list of available plans
    bolt plan run <plan> [params]    Run a Puppet task plan
    bolt file upload <src> <dest>    Upload a local file

where [options] are:
HELP

    TASK_HELP = <<-HELP.freeze
Usage: bolt task <action> <task> [options] [parameters]

Available actions are:
    show                             Show list of available tasks
    run                              Run a Puppet task

Parameters are of the form <parameter>=<value>.

Available options are:
HELP

    COMMAND_HELP = <<-HELP.freeze
Usage: bolt command <action> <command> [options]

Available actions are:
    run                              Run a command remotely

Available options are:
HELP

    SCRIPT_HELP = <<-HELP.freeze
Usage: bolt script <action> <script> [[arg1] ... [argN]] [options]

Available actions are:
    run                              Upload a local script and run it remotely

Available options are:
HELP

    PLAN_HELP = <<-HELP.freeze
Usage: bolt plan <action> <plan> [options] [parameters]

Available actions are:
    show                             Show list of available plans
    run                              Run a Puppet task plan

Parameters are of the form <parameter>=<value>.

Available options are:
HELP

    FILE_HELP = <<-HELP.freeze
Usage: bolt file <action> [options]

Available actions are:
    upload <src> <dest>              Upload local file <src> to <dest> on each node

Available options are:
HELP

    COMMANDS = { 'command' => %w[run],
                 'script'  => %w[run],
                 'task'    => %w[show run],
                 'plan'    => %w[show run],
                 'file'    => %w[upload] }.freeze
    TRANSPORTS = %w[ssh winrm pcp].freeze
    BOLTLIB_PATH = File.join(__FILE__, '../../../modules')

    attr_reader :parser, :config
    attr_accessor :options

    def initialize(argv)
      @argv    = argv
      @options = {
        nodes: []
      }
      @config = Bolt::Config.new
      @parser = create_option_parser(@options)
      @logger = Logger.new(STDERR)
    end

    def create_option_parser(results)
      OptionParser.new('') do |opts|
        opts.on(
          '-n', '--nodes NODES',
          'Node(s) to connect to in URI format [protocol://]host[:port]',
          'Eg. --nodes bolt.puppet.com',
          'Eg. --nodes localhost,ssh://nix.com:2222,winrm://windows.puppet.com',
          "\n",
          '* NODES can either be comma-separated, \'@<file>\' to read',
          '* nodes from a file, or \'-\' to read from stdin',
          '* Windows nodes must specify protocol with winrm://',
          '* protocol is `ssh` by default, may be `ssh` or `winrm`',
          '* port is `22` by default for SSH, `5985` for winrm (Optional)'
        ) do |nodes|
          results[:nodes] += parse_nodes(nodes)
          results[:nodes].uniq!
        end
        opts.on('-u', '--user USER',
                "User to authenticate as (Optional)") do |user|
          results[:user] = user
        end
        opts.on('-p', '--password [PASSWORD]',
                'Password to authenticate with (Optional).',
                'Omit the value to prompt for the password.') do |password|
          if password.nil?
            STDOUT.print "Please enter your password: "
            results[:password] = STDIN.noecho(&:gets).chomp
            STDOUT.puts
          else
            results[:password] = password
          end
        end
        opts.on('--private-key KEY',
                "Private ssh key to authenticate with (Optional)") do |key|
          results[:key] = key
        end
        opts.on('--tmpdir DIR',
                "The directory to upload and execute temporary files on the target(Optional)") do |tmpdir|
          results[:tmpdir] = tmpdir
        end
        opts.on('-c', '--concurrency CONCURRENCY', Integer,
                "Maximum number of simultaneous connections " \
                "(Optional, defaults to 100)") do |concurrency|
          results[:concurrency] = concurrency
        end
        opts.on('--connect-timeout TIMEOUT', Integer,
                "Connection timeout (Optional)") do |timeout|
          results[:connect_timeout] = timeout
        end
        opts.on('--modulepath MODULES',
                "List of directories containing modules, " \
                "separated by #{File::PATH_SEPARATOR}") do |modulepath|
          results[:modulepath] = modulepath.split(File::PATH_SEPARATOR)
        end
        opts.on('--params PARAMETERS',
                "Parameters to a task or plan") do |params|
          results[:task_options] = parse_params(params)
        end

        opts.on('--format FORMAT',
                "Output format to use: human or json") do |format|
          results[:format] = format
        end
        opts.on('-k', '--insecure',
                "Whether to connect insecurely ") do |insecure|
          results[:insecure] = insecure
        end
        opts.on('--transport TRANSPORT', TRANSPORTS,
                "Specify a default transport: #{TRANSPORTS.join(', ')}") do |t|
          results[:transport] = t
        end
        opts.on('--run-as USER',
                "User to run as using privilege escalation") do |user|
          results[:run_as] = user
        end
        opts.on('--sudo-password [PASSWORD]',
                'Password for privilege escalation') do |password|
          if results[:run_as].nil?
            @logger.warn("--sudo-password only provides privilege escalation
                        for a user specified by --run-as. Please include the
                        --run-as flag")
          end
          if password.nil?
            STDOUT.print "Please enter your privilege escalation password: "
            results[:sudo_password] = STDIN.noecho(&:gets).chomp
            STDOUT.puts
          else
            results[:sudo_password] = password
          end
        end
        opts.on('--configfile CONFIG_PATH',
                'Specify where to load the config file from') do |path|
          results[:configfile] = path
        end
        opts.on_tail('--[no-]tty',
                     "Request a pseudo TTY on nodes that support it") do |tty|
          results[:tty] = tty
        end
        opts.on_tail('--noop',
                     "Execute a task that supports it in noop mode") do |_|
          results[:noop] = true
        end
        opts.on_tail('-h', '--help', 'Display help') do |_|
          results[:help] = true
        end
        opts.on_tail('--verbose', 'Display verbose logging') do |_|
          results[:verbose] = true
        end
        opts.on_tail('--debug', 'Display debug logging') do |_|
          results[:debug] = true
        end
        opts.on_tail('--version', 'Display the version') do |_|
          puts Bolt::VERSION
          raise Bolt::CLIExit
        end
      end
    end

    def parse
      if @argv.empty?
        options[:help] = true
      end

      remaining = handle_parser_errors do
        parser.permute(@argv)
      end

      # Shortcut to handle help before other errors may be generated
      options[:mode] = remaining.shift

      if options[:mode] == 'help'
        options[:help] = true
        options[:mode] = remaining.shift
      end

      if options[:help]
        print_help(options[:mode])
        raise Bolt::CLIExit
      end

      @config.load_file(options[:configfile])
      @config.update_from_cli(options)
      @config.validate

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

      options
    end

    def print_help(mode)
      parser.banner = case mode
                      when 'task'
                        TASK_HELP
                      when 'command'
                        COMMAND_HELP
                      when 'script'
                        SCRIPT_HELP
                      when 'file'
                        FILE_HELP
                      when 'plan'
                        PLAN_HELP
                      else
                        BANNER
                      end
      puts parser.help
    end

    def parse_nodes(nodes)
      list = get_arg_input(nodes)
      list.split(/[[:space:],]+/).reject(&:empty?).uniq
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

      if options[:nodes].empty? && options[:mode] != 'plan' && options[:action] != 'show'
        raise Bolt::CLIError, "Option '--nodes' must be specified"
      end

      if %w[task plan].include?(options[:mode]) && @config[:modulepath].nil?
        raise Bolt::CLIError,
              "Option '--modulepath' must be specified when using" \
              " a task or plan"
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
    rescue OptionParser::InvalidOption => e
      raise Bolt::CLIError, "Unknown argument '#{e.args.first}'"
    end

    def execute(options)
      if options[:mode] == 'plan' || options[:mode] == 'task'
        begin
          require_relative '../../vendored/require_vendored'
        rescue LoadError
          raise Bolt::CLIError, "Puppet must be installed to execute tasks"
        end

        Puppet::Util::Log.newdestination(:console)
        Puppet[:log_level] = if @config[:log_level] == Logger::DEBUG
                               'debug'
                             else
                               'notice'
                             end
      end

      # ExecutionResult loaded here so that it can get puppet features if
      # puppet is present
      require 'bolt/execution_result'

      if options[:action] == 'show'
        if options[:mode] == 'task'
          if options[:object]
            outputter.print_task_info(get_task_info(options[:object]))
          else
            outputter.print_table(list_tasks)
            outputter.print_message("\nUse `bolt task show <task-name>` to view "\
                                  "details and parameters for a specific "\
                                  "task.")
          end
        elsif options[:mode] == 'plan'
          outputter.print_table(list_plans)
        end
        return
      end

      executor = Bolt::Executor.new(@config, options[:noop])

      if options[:mode] == 'plan'
        execute_plan(executor, options)
      else
        nodes = executor.from_uris(options[:nodes])

        results = nil
        outputter.print_head

        elapsed_time = Benchmark.realtime do
          results =
            case options[:mode]
            when 'command'
              executor.run_command(nodes, options[:object]) do |node, event|
                outputter.print_event(node, event)
              end
            when 'script'
              script = options[:object]
              validate_file('script', script)
              executor.run_script(
                nodes, script, options[:leftovers]
              ) do |node, event|
                outputter.print_event(node, event)
              end
            when 'task'
              execute_task(executor, options) do |node, event|
                outputter.print_event(node, event)
              end
            when 'file'
              src = options[:object]
              dest = options[:leftovers].first

              if dest.nil?
                raise Bolt::CLIError, "A destination path must be specified"
              end
              validate_file('source file', src)
              executor.file_upload(nodes, src, dest) do |node, event|
                outputter.print_event(node, event)
              end
            end
        end

        outputter.print_summary(results, elapsed_time)
      end
    rescue Bolt::CLIError => e
      outputter.fatal_error(e)
      raise e
    end

    def with_bolt_executor(executor, &block)
      Puppet.override(bolt_executor: executor, &block)
    end

    def execute_task(executor, options, &block)
      with_bolt_executor(executor) do
        run_task(options[:object],
                 options[:nodes],
                 options[:task_options],
                 &block)
      end
    rescue Puppet::Error
      raise Bolt::CLIError, "Exiting because of an error in Puppet code"
    end

    def execute_plan(executor, options)
      # Plans return null here?
      result = with_bolt_executor(executor) do
        run_plan(options[:object],
                 options[:task_options])
      end
      outputter.print_plan(result)
    rescue Puppet::Error
      raise Bolt::CLIError, "Exiting because of an error in Puppet code"
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
      @outputter ||= Bolt::Outputter.for_format(@config[:format])
    end

    def in_bolt_compiler(opts = [])
      Puppet.initialize_settings(opts)
      Puppet::Pal.in_tmp_environment('bolt', modulepath: [BOLTLIB_PATH] + @config[:modulepath], facts: {}) do |pal|
        pal.with_script_compiler do |compiler|
          yield compiler
        end
      end
    end

    def list_tasks
      in_bolt_compiler do |compiler|
        tasks = compiler.list_tasks
        tasks.map(&:name).sort.map do |task_name|
          task_sig = compiler.task_signature(task_name)
          [task_name, task_sig.task.description]
        end
      end
    rescue Puppet::Error
      raise Bolt::CLIError, "Failure while reading task metadata"
    end

    def list_plans
      in_bolt_compiler do |compiler|
        compiler.list_plans.map { |plan| [plan.name] }.sort
      end
    rescue Puppet::Error
      raise Bolt::CLIError, "Failure while reading plans"
    end

    def get_task_info(task_name)
      task = in_bolt_compiler do |compiler|
        compiler.task_signature(task_name)
      end
      raise Bolt::CLIError, "Could not find task #{task_name} in your modulepath" if task.nil?
      task.task_hash
    rescue Puppet::Error
      raise Bolt::CLIError, "Failure while reading task metadata"
    end

    def run_task(name, nodes, args, &block)
      parse_error = nil
      result = in_bolt_compiler do |compiler|
        begin
          compiler.call_function('run_task', name, nodes, args, &block)
        rescue Puppet::ParseError => e
          # we assume that the Puppet::ParseError is due to a problem with
          # the task and/or its parameters, but since the with_script_compiler
          # method rescues these errors and raises different ones instead,
          # we save it in a local variable and raise it as Bolt::CLIError
          # outside of the block
          parse_error = e
        end
      end
      raise Bolt::CLIError, parse_error.message if parse_error
      result
    end

    # Expects to be called with a configured Puppet compiler or error.instance? will fail
    def unwrap_execution_result(result)
      if result.instance_of? Bolt::ExecutionResult
        result.iterator.map do |node, output|
          if output.is_a?(Puppet::DataTypes::Error)
            # Get the original error hash used to initialize the Error type object.
            result = output.partial_result || {}
            result[:_error] = { msg: output.message,
                                kind: output.kind,
                                details: output.details,
                                issue_code: output.issue_code }
            { node: node, status: 'failed', result: result }
          else
            { node: node, status: 'finished', result: output }
          end
        end
      else
        result
      end
    end

    def run_plan(plan, args)
      Dir.mktmpdir('bolt') do |dir|
        cli = []
        Puppet::Settings::REQUIRED_APP_SETTINGS.each do |setting|
          cli << "--#{setting}" << dir
        end
        in_bolt_compiler(cli) do |compiler|
          result = compiler.call_function('run_plan', plan, args)
          # Querying ExecutionResult for failures currently requires a script compiler.
          # Convert from an ExecutionResult to structured output that we can print.
          unwrap_execution_result(result)
        end
      end
    end
  end
end
