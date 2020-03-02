# frozen_string_literal: true

require 'bolt/error'
require 'bolt/config/transport'

module Bolt
  class Config
    class Sudoable < Transport
      private def validate
        run_as_cmd = config['run-as-command']
        if run_as_cmd && (!run_as_cmd.is_a?(Array) || run_as_cmd.any? { |n| !n.is_a?(String) })
          raise Bolt::ValidationError,
                "run-as-command must be an Array of Strings, received #{run_as_cmd.class} #{run_as_cmd.inspect}"
        end
      end
    end
  end
end
