require 'trollop'
require 'uri'
require 'puppet_bolt/node'
require 'puppet_bolt/version'
require 'puppet_bolt/executor'

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
        options[:task_options] = Hash[task_options.map { |arg| arg.split('=') }]
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

    def self.parse_uri(node)
      case node
      when %r{^(ssh|winrm)://.*:\d+$}
        URI(node)
      when %r{^(ssh|winrm)://}
        uri = URI(node)
        uri.port = uri.scheme == 'ssh' ? 22 : 5985
        uri
      when /.*:\d+$/
        URI("ssh://#{node}")
      else
        URI("ssh://#{node}:22")
      end
    end

    def execute(options)
      nodes = options[:nodes].map do |node|
        uri = self.class.parse_uri(node)
        if uri.scheme == 'winrm'
          endpoint = "http://#{uri.host}:#{uri.port}/wsman"
          Bolt::WinRM.new(endpoint,
                          options[:user],
                          options[:password])
        else
          Bolt::SSH.new(uri.host,
                        options[:user],
                        uri.port,
                        options[:password])
        end
      end

      Bolt::Executor.new(nodes).execute(options[:task_options]["command"])
    end
  end
end
