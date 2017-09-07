require 'logger'

module Bolt
  class Node
    STDIN_METHODS       = %w[both stdin].freeze
    ENVIRONMENT_METHODS = %w[both environment].freeze

    def self.parse_uri(node)
      case node
      when %r{^(ssh|winrm|docker)://.*:\d+$}
        URI(node)
      when %r{^(ssh|winrm|docker)://}
        uri = URI(node)
        uri.port = uri.scheme == 'ssh' ? 22 : 5985
        uri
      when /.*:\d+$/
        URI("ssh://#{node}")
      else
        URI("ssh://#{node}:22")
      end
    end

    def self.from_uri(uri_string, user, password)
      uri = parse_uri(uri_string)
      klass = if uri.scheme == 'winrm'
                Bolt::WinRM
              elsif uri.scheme == 'docker'
                Bolt::Docker
              else
                Bolt::SSH
              end
      klass.new(uri.host, uri.port, user, password)
    end

    attr_reader :logger, :host

    def initialize(host, port = nil, user = nil, password = nil)
      @host = host
      @user = user
      @port = port
      @password = password

      @logger = init_logger(STDERR, Logger::DEBUG)
      @transport_logger = init_logger(STDERR, Logger::WARN)
    end

    def init_logger(destination = STDERR, level = Logger::WARN)
      logger = Logger.new(destination)
      logger.level = level
      logger.formatter = proc do |severity, datetime, _, msg|
        "#{datetime} #{severity} #{@host}: #{msg}\n"
      end
      logger
    end
  end
end

require 'bolt/node/ssh'
require 'bolt/node/winrm'
require 'bolt/node/docker'
