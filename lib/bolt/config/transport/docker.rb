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
          stream
          tmpdir
          tty
        ].freeze

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
