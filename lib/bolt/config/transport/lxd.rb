# frozen_string_literal: true

require_relative '../../../bolt/error'
require_relative '../../../bolt/config/transport/base'

module Bolt
  class Config
    module Transport
      class LXD < Base
        OPTIONS = %w[
          cleanup
          interpreters
          remote
          shell-command
          tmpdir
          tty
        ].concat(RUN_AS_OPTIONS).sort.freeze

        DEFAULTS = {
          'cleanup' => true,
          'remote'  => 'local'
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
