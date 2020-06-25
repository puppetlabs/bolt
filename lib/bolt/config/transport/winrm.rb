# frozen_string_literal: true

require 'bolt/error'
require 'bolt/config/transport/base'

module Bolt
  class Config
    module Transport
      class WinRM < Base
        OPTIONS = %w[
          basic-auth-only
          cacert
          cleanup
          connect-timeout
          extensions
          file-protocol
          host
          interpreters
          password
          port
          realm
          smb-port
          ssl
          ssl-verify
          tmpdir
          user
        ].freeze

        DEFAULTS = {
          "basic-auth-only" => false,
          "cleanup"         => true,
          "connect-timeout" => 10,
          "ssl"             => true,
          "ssl-verify"      => true,
          "file-protocol"   => "winrm"
        }.freeze

        private def validate
          super

          if @config['ssl']
            if @config['file-protocol'] == 'smb'
              raise Bolt::ValidationError, "SMB file transfers are not allowed with SSL enabled"
            end

            if @config['cacert']
              @config['cacert'] = File.expand_path(@config['cacert'], @project)
              Bolt::Util.validate_file('cacert', @config['cacert'])
            end
          end

          if !@config['ssl'] && @config['basic-auth-only']
            raise Bolt::ValidationError, "Basic auth is only allowed when using SSL"
          end

          if @config['interpreters']
            @config['interpreters'] = normalize_interpreters(@config['interpreters'])
          end
        end
      end
    end
  end
end
