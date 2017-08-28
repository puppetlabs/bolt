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

    MODES = %w[run exec script].freeze

    def parse
      parser = Trollop::Parser.new do
        banner <<-END
Runs ad-hoc tasks on your nodes over SSH and WinRM.

Usage:
       bolt exec [options] command=<command>

where [options] are:
END
        version Bolt::VERSION

        opt :nodes, "Nodes to connect to", type: :strings, required: true
        opt :user, "User to authenticate as (Optional)", type: :string
        opt :password, "Password to authenticate as (Optional)", type: :string
      end

      task_options, global_options = @argv.partition { |arg| arg =~ /=/ }
      begin
        raise Trollop::HelpNeeded if @argv.empty? # show help screen

        options = parser.parse(global_options)
        options[:leftovers] = parser.leftovers
        options[:mode] = get_mode(parser.leftovers)
        options[:task_options] = Hash[task_options.map { |a| a.split('=', 2) }]
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
        end

      results.each_pair do |node, result|
        $stdout.print "#{node.host}: "
        result.print_to_stream($stdout)
      end
    end
  end
end
