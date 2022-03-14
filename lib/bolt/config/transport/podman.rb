# frozen_string_literal: true

require_relative '../../../bolt/error'
require_relative '../../../bolt/config/transport/base'

module Bolt
  class Config
    module Transport
      class Podman < Base
        OPTIONS = %w[
          cleanup
          host
          interpreters
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
        end
      end
    end
  end
end
