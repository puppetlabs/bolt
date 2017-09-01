require 'trollop'
require 'uri'
require 'bolt/node'
require 'bolt/version'
require 'bolt/executor'

module Bolt
  class CLIError < RuntimeError
    attr_reader :error_code

    def initialize(msg, error_code)
      super(msg)
      @error_code = error_code
    end
  end

  class CLIExit < StandardError; end

  class CLI
    def initialize(argv)
      @argv = argv
    end

    MODES = %w[run exec script task].freeze

    def parse
      parser = Trollop::Parser.new do
        banner <<-END
Runs ad-hoc tasks on your nodes over SSH and WinRM.

Usage:
       bolt exec [options] command=<command>

where [options] are:
END
        version Bolt::VERSION

        opt :nodes, "Nodes to connect to", type: :string, required: true
        opt :user, "User to authenticate as (Optional)", type: :string
        opt :password, "Password to authenticate as (Optional)", type: :string
        opt :modules, "Path to modules directory", type: :string
      end

      task_options, global_options = @argv.partition { |arg| arg =~ /=/ }
      begin
        raise Trollop::HelpNeeded if @argv.empty? # show help screen

        options = parser.parse(global_options)
        options[:leftovers] = parser.leftovers
        options[:mode] = get_mode(parser.leftovers)
        options[:task_options] = Hash[task_options.map { |a| a.split('=', 2) }]
        options[:nodes] = options[:nodes].split(',')
        options
      rescue Trollop::CommandlineError => e
        raise Bolt::CLIError.new(e.message, 1)
      rescue Trollop::HelpNeeded
        parser.educate
        raise Bolt::CLIExit
      rescue Trollop::VersionNeeded
        puts parser.version
        raise Bolt::CLIExit
      end
    end

    def get_mode(args)
      if MODES.include?(args[0])
        args.shift
      else
        raise Bolt::CLIError.new("Expected a mode of run, exec, or script", 1)
      end
    end

    def execute(options)
      nodes = options[:nodes].map do |node|
        Bolt::Node.from_uri(node, options[:user], options[:password])
      end

      executor = Bolt::Executor.new(nodes)
      results =
        case options[:mode]
        when 'exec'
          executor.execute(options[:task_options]["command"])
        when 'script'
          executor.run_script(options[:task_options]["script"])
        when 'task'
          path = options[:leftovers][0]
          input_method = nil

          unless task_file?(path)
            path, metadata = load_task_data(path, options[:modules])
            input_method = metadata['input_method']
          end

          input_method ||= 'both'
          executor.run_task(path, input_method, options[:task_options])
        end

      results.each_pair do |node, result|
        $stdout.print "#{node.host}: "
        result.print_to_stream($stdout)
      end
    end

    def task_file?(path)
      File.exist?(path)
    end

    def load_task_data(name, modules)
      if modules.nil?
        raise Bolt::CLIError.new(
          "The '--modules' option must be specified to run a task", 1
        )
      end

      begin
        require 'puppet'
        require 'puppet/node/environment'
        require 'puppet/info_service'
      rescue LoadError
        raise Bolt::CLIError.new("Puppet must be installed to execute tasks", 1)
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
          raise Bolt::CLIError.new(
            "Failed to load task file for '#{name}'", 1
          )
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
