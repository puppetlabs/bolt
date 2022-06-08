# frozen_string_literal: true

require_relative '../../../bolt/error'
require_relative '../../../bolt/config/transport/base'

module Bolt
  class Config
    module Transport
      class Local < Base
        WINDOWS_OPTIONS = %w[
          bundled-ruby
          cleanup
          extensions
          interpreters
          tmpdir
        ].freeze

        OPTIONS = WINDOWS_OPTIONS.dup.concat(RUN_AS_OPTIONS).sort.freeze

        DEFAULTS = {
          'bundled-ruby' => true,
          'cleanup' => true
        }.freeze

        def self.options
          Bolt::Util.windows? ? WINDOWS_OPTIONS : OPTIONS
        end

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
