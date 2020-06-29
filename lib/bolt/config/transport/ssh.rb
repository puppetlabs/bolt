# frozen_string_literal: true

require 'bolt/error'
require 'bolt/config/transport/base'

module Bolt
  class Config
    module Transport
      class SSH < Base
        # Options available when using the net-ssh-based transport
        OPTIONS = %w[
          cleanup
          connect-timeout
          disconnect-timeout
          encryption-algorithms
          extensions
          host
          host-key-algorithms
          host-key-check
          interpreters
          kex-algorithms
          load-config
          login-shell
          mac-algorithms
          password
          port
          private-key
          proxyjump
          script-dir
          tmpdir
          tty
          user
        ].concat(RUN_AS_OPTIONS).sort.freeze

        # Options available when using the external ssh transport
        EXTERNAL_OPTIONS = %w[
          cleanup
          copy-command
          host
          host-key-check
          interpreters
          port
          private-key
          script-dir
          ssh-command
          tmpdir
          user
        ].concat(RUN_AS_OPTIONS).sort.freeze

        DEFAULTS = {
          "cleanup"            => true,
          "connect-timeout"    => 10,
          "disconnect-timeout" => 5,
          "load-config"        => true,
          "login-shell"        => 'bash',
          "tty"                => false
        }.freeze

        # The set of options available for the ssh and external ssh transports overlap, so we
        # need to check which transport is used before fully initializing, otherwise options
        # may not be filtered correctly.
        def initialize(data = {}, project = nil)
          assert_hash_or_config(data)
          @external = true if data['ssh-command']
          super(data, project)
        end

        private def filter(unfiltered)
          @external ? unfiltered.slice(*EXTERNAL_OPTIONS) : unfiltered.slice(*OPTIONS)
        end

        private def validate
          super

          if (key_opt = @config['private-key'])
            unless key_opt.instance_of?(String) || (key_opt.instance_of?(Hash) && key_opt.include?('key-data'))
              raise Bolt::ValidationError,
                    "private-key option must be a path to a private key file or a Hash containing the 'key-data', "\
                    "received #{key_opt.class} #{key_opt}"
            end

            if key_opt.instance_of?(String)
              @config['private-key'] = File.expand_path(key_opt, @project)

              # We have an explicit test for this to only warn if using net-ssh transport
              Bolt::Util.validate_file('ssh key', @config['private-key']) if @config['ssh-command']
            end

            if key_opt.instance_of?(Hash) && @config['ssh-command']
              raise Bolt::ValidationError, 'private-key must be a filepath when using ssh-command'
            end
          end

          if @config['interpreters']
            @config['interpreters'] = normalize_interpreters(@config['interpreters'])
          end

          if @config['login-shell'] && !LOGIN_SHELLS.include?(@config['login-shell'])
            raise Bolt::ValidationError,
                  "Unsupported login-shell #{@config['login-shell']}. Supported shells are #{LOGIN_SHELLS.join(', ')}"
          end

          %w[encryption-algorithms host-key-algorithms kex-algorithms mac-algorithms run-as-command].each do |opt|
            next unless @config.key?(opt)
            unless @config[opt].all? { |n| n.is_a?(String) }
              raise Bolt::ValidationError,
                    "#{opt} must be an Array of Strings, received #{@config[opt].inspect}"
            end
          end

          if @config['login-shell'] == 'powershell'
            %w[tty run-as].each do |key|
              if @config[key]
                raise Bolt::ValidationError,
                      "#{key} is not supported when using PowerShell"
              end
            end
          end

          if @config['ssh-command'] && !@config['load-config']
            msg = 'Cannot use external SSH transport with load-config set to false'
            raise Bolt::ValidationError, msg
          end
        end
      end
    end
  end
end
