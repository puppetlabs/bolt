# frozen_string_literal: true

require 'bolt/node/errors'
require 'bolt/transport/sudoable'
require 'json'
require 'shellwords'

module Bolt
  module Transport
    class SSH < Sudoable
      def self.options
        %w[host port user password sudo-password private-key host-key-check
           connect-timeout disconnect-timeout tmpdir script-dir run-as tty run-as-command proxyjump interpreters]
      end

      def self.default_options
        {
          'connect-timeout' => 10,
          'tty' => false,
          'load-config' => true,
          'disconnect-timeout' => 5
        }
      end

      def provided_features
        ['shell']
      end

      def self.validate(options)
        validate_sudo_options(options)

        host_key = options['host-key-check']
        unless host_key.nil? || !!host_key == host_key
          raise Bolt::ValidationError, 'host-key-check option must be a Boolean true or false'
        end

        if (key_opt = options['private-key'])
          unless key_opt.instance_of?(String) || (key_opt.instance_of?(Hash) && key_opt.include?('key-data'))
            raise Bolt::ValidationError,
                  "private-key option must be the path to a private key file or a hash containing the 'key-data'"
          end
        end

        %w[connect-timeout disconnect-timeout].each do |timeout|
          timeout_value = options[timeout]
          unless timeout_value.is_a?(Integer) || timeout_value.nil?
            error_msg = "#{timeout} value must be an Integer, received #{timeout_value}:#{timeout_value.class}"
            raise Bolt::ValidationError, error_msg
          end
        end

        if (dir_opt = options['script-dir'])
          unless dir_opt.is_a?(String) && !dir_opt.empty?
            raise Bolt::ValidationError, "script-dir option must be a non-empty string"
          end
        end
      end

      def initialize
        super

        require 'net/ssh'
        require 'net/scp'
        begin
          require 'net/ssh/krb'
        rescue LoadError
          logger.debug("Authentication method 'gssapi-with-mic' (Kerberos) is not available.")
        end

        @transport_logger = Logging.logger[Net::SSH]
        @transport_logger.level = :warn
      end

      def with_connection(target)
        conn = Connection.new(target, @transport_logger)
        conn.connect
        yield conn
      ensure
        begin
          conn&.disconnect
        rescue StandardError => e
          logger.info("Failed to close connection to #{target.safe_name} : #{e.message}")
        end
      end

      def connected?(target)
        with_connection(target) { true }
      rescue Bolt::Node::ConnectError
        false
      end
    end
  end
end

require 'bolt/transport/ssh/connection'
