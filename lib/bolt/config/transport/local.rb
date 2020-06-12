# frozen_string_literal: true

require 'bolt/error'
require 'bolt/config/transport/base'

module Bolt
  class Config
    module Transport
      class Local < Base
        OPTIONS = %w[
          cleanup
          interpreters
          run-as
          run-as-command
          sudo-executable
          sudo-password
          tmpdir
        ].freeze

        WINDOWS_OPTIONS = %w[
          cleanup
          interpreters
          tmpdir
        ].freeze

        DEFAULTS = {
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

          if (run_as_cmd = @config['run-as-command'])
            unless run_as_cmd.all? { |n| n.is_a?(String) }
              raise Bolt::ValidationError,
                    "run-as-command must be an Array of Strings, received #{run_as_cmd.class} #{run_as_cmd.inspect}"
            end
          end
        end
      end
    end
  end
end
