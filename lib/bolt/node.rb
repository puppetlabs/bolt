require 'bolt/result'
require 'bolt/config'
require 'bolt/target'
require 'logging'

module Bolt
  class Node
    STDIN_METHODS       = %w[both stdin].freeze
    ENVIRONMENT_METHODS = %w[both environment].freeze

    def self.from_target(target)
      klass = case target.protocol
              when 'winrm'
                Bolt::WinRM
              when 'pcp'
                Bolt::Orch
              else
                Bolt::SSH
              end
      klass.new(target)
    end

    def self.initialize_transport(_logger); end

    attr_reader :logger, :user, :password, :connect_timeout, :target, :run_as

    def initialize(target)
      @target = target

      transport_conf = target.options
      @user = @target.user
      @password = @target.password
      @key = transport_conf[:key]
      @cacert = transport_conf[:cacert]
      @tty = transport_conf[:tty]
      @host_key_check = transport_conf[:host_key_check]
      @ssl = transport_conf[:ssl]
      @connect_timeout = transport_conf[:connect_timeout]
      @sudo_password = transport_conf[:sudo_password]
      @run_as = transport_conf[:run_as]
      @conf_run_as = transport_conf[:run_as]
      @tmpdir = transport_conf[:tmpdir]
      @service_url = transport_conf[:service_url]
      @token_file = transport_conf[:token_file]
      @orch_task_environment = transport_conf[:orch_task_environment]
      @extensions = transport_conf[:extensions]

      @logger = Logging.logger[@target.host]
    end

    def uri
      @target.uri
    end

    def upload(_source, _destination)
      raise NotImplementedError, 'transports must implement upload(source, destination)'
    end

    def run_command(_command, _options = nil)
      raise NotImplementedError, 'transports must implement run_command(command, options = nil)'
    end

    def run_script(_script, _arguments, _options = nil)
      raise NotImplementedError, 'transports must implement run_script(script, arguments, options = nil)'
    end

    def run_task(_task, _input_method, _arguments, _options = nil)
      raise NotImplementedError, 'transports must implement run_task(task, input_method, arguments, options = nil)'
    end
  end
end

require 'bolt/node/errors'
require 'bolt/node/ssh'
require 'bolt/node/winrm'
require 'bolt/node/orch'
