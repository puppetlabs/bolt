# frozen_string_literal: true

require 'bolt/error'
require 'bolt/config/transport/base'

module Bolt
  class Config
    module Transport
      class Docker < Base
        OPTIONS = %w[
          cleanup
          host
          interpreters
          service-url
          shell-command
          tmpdir
          tty
        ].concat(RUN_AS_OPTIONS).sort.freeze

        DEFAULTS = {
          'cleanup' => true
        }.freeze

        private def validate
          super

          if @config['interpreters']
            @config['interpreters'] = normalize_interpreters(@config['interpreters'])
          end

          if Bolt::Util.windows? && @config['run-as']
            raise Bolt::ValidationError, "run-as is not supported when using PowerShell"
          end
        end
      end
    end
  end
end
