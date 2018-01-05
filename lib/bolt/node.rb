require 'bolt/logger'
require 'bolt/node_uri'
require 'bolt/result'
require 'bolt/config'
require 'bolt/target'

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

    attr_reader :logger, :host, :port, :uri, :user, :password, :connect_timeout

    def initialize(host, port = nil, user = nil, password = nil, uri: nil,
                   config: Bolt::Config.new)
      @host = host
      @port = port
      @uri = uri

      transport_conf = config[:transports][protocol.to_sym]
      @user = user || transport_conf[:user]
      @password = password || transport_conf[:password]
      @key = transport_conf[:key]
      @cacert = transport_conf[:cacert]
      @tty = transport_conf[:tty]
      @insecure = transport_conf[:insecure]
      @connect_timeout = transport_conf[:connect_timeout]
      @sudo_password = transport_conf[:sudo_password]
      @run_as = transport_conf[:run_as]
      @tmpdir = transport_conf[:tmpdir]
      @service_url = transport_conf[:service_url]
      @token_file = transport_conf[:token_file]
      @orch_task_environment = transport_conf[:orch_task_environment]

      @logger = Logger.get_logger(progname: @host)
      @transport_logger = Logger.get_logger(progname: @host, log_level: Logger::WARN)
    end

    def upload(source, destination)
      @logger.debug { "Uploading #{source} to #{destination}" }
      result = _upload(source, destination)
      if result.success?
        Bolt::Result.new(nil, "Uploaded '#{source}' to '#{host}:#{destination}'")
      else
        result
      end
    end

    def run_command(command)
      _run_command(command)
    end

    def run_script(script, arguments)
      _run_script(script, arguments)
    end

    def run_task(task, input_method, arguments)
      _run_task(task, input_method, arguments)
    end
  end
end

require 'bolt/node/errors'
require 'bolt/node/ssh'
require 'bolt/node/winrm'
require 'bolt/node/orch'
