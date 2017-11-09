require 'logger'
require 'bolt/node_uri'
require 'bolt/formatter'
require 'bolt/result'
require 'bolt/config'

module Bolt
  class Node
    STDIN_METHODS       = %w[both stdin].freeze
    ENVIRONMENT_METHODS = %w[both environment].freeze

    def self.from_uri(uri_string, **kwargs)
      uri = NodeURI.new(uri_string, kwargs[:config][:transport])
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
                uri.user,
                uri.password,
                uri: uri_string,
                **kwargs)
    end

    def self.initialize_transport(_logger); end

    attr_reader :logger, :host, :uri, :user, :password

    def initialize(host, port = nil, user = nil, password = nil, uri: nil,
                   config: Bolt::Config.new)
      @host = host
      @port = port
      @user = user || config[:user]
      @password = password || config[:password]
      @key = config[:key]
      @tty = config[:tty]
      @insecure = config[:insecure]
      @uri = uri

      @logger = init_logger(config[:log_destination], config[:log_level])
      @transport_logger = init_logger(config[:log_destination], Logger::WARN)
    end

    def init_logger(destination, level)
      logger = Logger.new(destination)
      logger.progname = @host
      logger.level = level
      logger.formatter = Bolt::Formatter.new
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

    def run_script(script, arguments)
      _run_script(script, arguments).to_command_result
    end

    def run_task(task, input_method, arguments)
      _run_task(task, input_method, arguments).to_task_result
    end
  end
end

require 'bolt/node/errors'
require 'bolt/node/ssh'
require 'bolt/node/winrm'
require 'bolt/node/orch'
