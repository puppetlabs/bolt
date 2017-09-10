require 'logger'
require 'bolt/node_uri'
require 'bolt/node/formatter'
require 'bolt/result'

module Bolt
  class Node
    STDIN_METHODS       = %w[both stdin].freeze
    ENVIRONMENT_METHODS = %w[both environment].freeze

    def self.from_uri(uri_string, default_user = nil, default_password = nil,
                      **kwargs)
      uri = NodeURI.new(uri_string)
      klass = case uri.scheme
              when 'winrm'
                Bolt::WinRM
              when 'pcp'
                Bolt::Orch
              else
                Bolt::SSH
              end
      klass.new(uri.hostname,
                uri.port,
                uri.user || default_user || Bolt.config[:user],
                uri.password || default_password || Bolt.config[:password],
                uri: uri_string, **kwargs)
    end

    attr_reader :logger, :host, :uri, :user, :password

    def initialize(host, port = nil, user = nil,
                   password = nil, tty: false, uri: nil,
                   log_level: Bolt.log_level || Logger::WARN)
      @host = host
      @user = user
      @port = port
      @password = password
      @tty = tty
      @uri = uri

      @logger = init_logger(level: log_level)
      @transport_logger = init_logger(level: Logger::WARN)
    end

    def init_logger(destination: STDERR, level: Logger::WARN)
      logger = Logger.new(destination)
      logger.level = level
      logger.formatter = Bolt::Node::Formatter.new(@host)
      logger
    end

    def upload(source, destination)
      @logger.debug { "Uploading #{source} to #{destination}" }
      result = _upload(source, destination)
      if result.success?
        Bolt::Result.new("Uploaded '#{source}' to '#{host}:#{destination}'")
      else
        result.to_result
      end
    end

    def run_command(command)
      @logger.info { "Running command: #{command}" }
      _run_command(command).to_command_result
    end

    def run_script(script)
      _run_script(script).to_command_result
    end

    def run_task(task, input_method, arguments)
      _run_task(task, input_method, arguments).to_task_result
    end
  end
end

require 'bolt/node/ssh'
require 'bolt/node/winrm'
require 'bolt/node/orch'
