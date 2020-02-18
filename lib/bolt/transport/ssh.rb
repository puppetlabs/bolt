# frozen_string_literal: true

require 'bolt/node/errors'
require 'bolt/transport/sudoable'
require 'json'
require 'shellwords'

module Bolt
  module Transport
    class SSH < Sudoable
      OPTIONS = {
        "connect-timeout"    => "How long to wait when establishing connections.",
        "disconnect-timeout" => "How long to wait before force-closing a connection.",
        "host"               => "Host name.",
        "host-key-check"     => "Whether to perform host key validation when connecting.",
        "interpreters"       => "A map of an extension name to the absolute path of an executable, "\
                                "enabling you to override the shebang defined in a task executable. The "\
                                "extension can optionally be specified with the `.` character (`.py` and "\
                                "`py` both map to a task executable `task.py`) and the extension is case "\
                                "sensitive. When a target's name is `localhost`, Ruby tasks run with the "\
                                "Bolt Ruby interpreter by default.",
        "load-config"        => "Whether to load system SSH configuration.",
        "password"           => "Login password.",
        "port"               => "Connection port.",
        "private-key"        => "Either the path to the private key file to use for authentication, or a "\
                                "hash with the key `key-data` and the contents of the private key.",
        "proxyjump"          => "A jump host to proxy connections through, and an optional user to "\
                                "connect with.",
        "run-as"             => "A different user to run commands as after login.",
        "run-as-command"     => "The command to elevate permissions. Bolt appends the user and command "\
                                "strings to the configured `run-as-command` before running it on the "\
                                "target. This command must not require an interactive password prompt, "\
                                "and the `sudo-password` option is ignored when `run-as-command` is "\
                                "specified. The `run-as-command` must be specified as an array.",
        "script-dir"         => "The subdirectory of the tmpdir to use in place of a randomized "\
                                "subdirectory for uploading and executing temporary files on the "\
                                "target. It's expected that this directory already exists as a subdir "\
                                "of tmpdir, which is either configured or defaults to `/tmp`.",
        "sudo-executable"    => "The executable to use when escalating to the configured `run-as` "\
                                "user. This is useful when you want to escalate using the configured "\
                                "`sudo-password`, since `run-as-command` does not use `sudo-password` "\
                                "or support prompting. The command executed on the target is "\
                                "`<sudo-executable> -S -u <user> -p custom_bolt_prompt <command>`. "\
                                "**This option is experimental.**",
        "sudo-password"      => "Password to use when changing users via `run-as`.",
        "tmpdir"             => "The directory to upload and execute temporary files on the target.",
        "tty"                => "Request a pseudo tty for the session. This option is generally "\
                                "only used in conjunction with the `run-as` option when the sudoers "\
                                "policy requires a `tty`.",
        "user"               => "Login user."
      }.freeze

      def self.options
        OPTIONS.keys
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
