require 'logger'

module Bolt
  class Node
    STDIN_METHODS       = %w[both stdin].freeze
    ENVIRONMENT_METHODS = %w[both environment].freeze

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

    def self.from_uri(uri_string, user, password, tty)
      uri = parse_uri(uri_string)
      klass = if uri.scheme == 'winrm'
                Bolt::WinRM
              else
                Bolt::SSH
              end
      klass.new(uri.host, uri.port, user, password, tty)
    end

    attr_reader :logger, :host

    def initialize(host, port = nil, user = nil, password = nil, tty = nil)
      @host = host
      @user = user
      @port = port
      @password = password
      @tty = tty

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
