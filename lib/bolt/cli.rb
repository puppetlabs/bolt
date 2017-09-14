require 'uri'
require 'optparse'
require 'benchmark'
require 'bolt/node'
require 'bolt/version'
require 'bolt/executor'

module Bolt
  class CLIError < RuntimeError
    attr_reader :error_code

    def initialize(msg, error_code: 1)
      super(msg)
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
    bolt task run <task> [params]    Run a Puppet Task
    bolt file upload <src> <dest>    Upload a local file

where [options] are:
HELP

    TASK_HELP = <<-HELP.freeze
Usage: bolt task <action> [options] [parameters]

Available actions are:
    run                              Run a task

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
Usage: bolt script <action> <script> [options]

Available actions are:
    run                              Upload a local script and run it remotely

Available options are:
HELP

    FILE_HELP = <<-HELP.freeze
Usage: bolt file <action> [options]

Available actions are:
    upload <src> <dest>              Upload local file <src> to <dest> on each node

Available options are:
HELP

    def initialize(argv)
      @argv = argv
    end

    MODES = %w[command script task file].freeze
    ACTIONS = %w[run upload download].freeze

    def parse
      options = {}

      global = OptionParser.new('') do |opts|
        opts.on('-n', '--nodes x,y,z', Array, 'Nodes to connect to') do |nodes|
          options[:nodes] = nodes
        end
        opts.on('-u', '--user USER',
                "User to authenticate as (Optional)") do |user|
          options[:user] = user
        end
        opts.on('-p', '--password PASSWORD',
                "Password to authenticate as (Optional)") do |password|
          options[:password] = password
        end
        opts.on('--modules MODULES', "Path to modules directory") do |modules|
          options[:modules] = modules
        end
        opts.on_tail('--[no-]tty',
                     "Reuqest a pseudo TTY on nodes that support it") do |tty|
          options[:tty] = tty
        end
        opts.on_tail('-h', '--help', 'Display help') do |_|
          options[:help] = true
        end
        opts.on_tail('--version', 'Display the version') do |_|
          puts Bolt::VERSION
          raise Bolt::CLIExit
        end
      end

      if @argv.empty?
        options[:help] = true
      end

      remaining = handle_parser_errors do
        global.permute(@argv)
      end

      options[:mode] = remaining.shift
      options[:action] = remaining.shift
      options[:object] = remaining.shift

      if options[:help]
        global.banner = case options[:mode]
                        when 'task'
                          TASK_HELP
                        when 'command'
                          COMMAND_HELP
                        when 'script'
                          SCRIPT_HELP
                        when 'file'
                          FILE_HELP
                        else
                          BANNER
                        end
        puts global.help
        raise Bolt::CLIExit
      end

      task_options, remaining = remaining.partition { |s| s =~ /.+=/ }
      options[:task_options] = Hash[task_options.map { |a| a.split('=', 2) }]

      options[:leftovers] = remaining

      validate(options)

      options
    end

    def validate(options)
      unless MODES.include?(options[:mode])
        raise Bolt::CLIError, "Expected mode to be one of #{MODES.join(', ')}"
      end

      unless ACTIONS.include?(options[:action])
        raise Bolt::CLIError,
              "Expected action to be one of #{ACTIONS.join(', ')}"
      end

      if options[:mode] != 'file' && !options[:leftovers].empty?
        raise Bolt::CLIError,
              "unknown argument(s) #{options[:leftovers].join(', ')}"
      end

      unless options[:nodes]
        raise Bolt::CLIError, "option --nodes must be specified"
      end
    end

    def handle_parser_errors
      yield
    rescue OptionParser::MissingArgument => e
      raise Bolt::CLIError, "option '#{e.args.first}' needs a parameter"
    rescue OptionParser::InvalidOption => e
      raise Bolt::CLIError, "unknown argument '#{e.args.first}'"
    end

    def execute(options)
      nodes = options[:nodes].map do |node|
        Bolt::Node.from_uri(node,
                            options[:user], options[:password], options[:tty])
      end

      results = nil
      elapsed_time = Benchmark.realtime do
        executor = Bolt::Executor.new(nodes)
        results =
          case options[:mode]
          when 'command'
            executor.execute(options[:object])
          when 'script'
            executor.run_script(options[:object])
          when 'task'
            path = options[:object]
            input_method = nil

            unless file_exist?(path)
              path, metadata = load_task_data(path, options[:modules])
              input_method = metadata['input_method']
            end

            input_method ||= 'both'
            executor.run_task(path, input_method, options[:task_options])
          when 'file'
            src = options[:object]
            dest = options[:leftovers].first

            if dest.nil?
              raise Bolt::CLIError, "A destination path must be specified"
            elsif !file_exist?(src)
              raise Bolt::CLIError, "The source file '#{src}' does not exist"
            end

            executor.file_upload(src, dest)
          end
      end

      print_results(results, elapsed_time)
    end

    def print_results(results, elapsed_time)
      results.each_pair do |node, result|
        result.colorize($stdout) { $stdout.puts "#{node.host}:" }
        $stdout.puts
        result.print_to_stream($stdout)
        $stdout.puts
      end

      $stdout.puts format("Ran on %d node%s in %.2f seconds",
                          results.size,
                          results.size > 1 ? 's' : '',
                          elapsed_time)
    end

    def file_exist?(path)
      File.exist?(path)
    end

    def load_task_data(name, modules)
      if modules.nil?
        raise Bolt::CLIError,
              "The '--modules' option must be specified to run a task"
      end

      begin
        require 'puppet'
        require 'puppet/node/environment'
        require 'puppet/info_service'
      rescue LoadError
        raise Bolt::CLIError, "Puppet must be installed to execute tasks"
      end

      module_name, file_name = name.split('::', 2)
      file_name ||= 'init'

      env = Puppet::Node::Environment.create('bolt', [modules])
      Puppet.override(environments: Puppet::Environments::Static.new(env)) do
        data = Puppet::InfoService::TaskInformationService.task_data(
          env.name, module_name, name
        )

        file = data[:files].find { |f| File.basename(f, '.*') == file_name }
        if file.nil?
          raise Bolt::CLIError, "Failed to load task file for '#{name}'"
        end

        metadata =
          if data[:metadata_file]
            JSON.parse(File.read(data[:metadata_file]))
          else
            {}
          end

        [file, metadata]
      end
    end
  end
end
