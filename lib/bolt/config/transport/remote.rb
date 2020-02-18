# frozen_string_literal: true

require 'bolt/error'
require 'bolt/config/transport'

module Bolt
  class Config
    class Remote < Transport
      OPTIONS = {
        "run-on" => "The proxy target that the task executes on."
      }.freeze

      DEFAULTS = {
        "run-on" => "localhost"
      }.freeze

      private def validate
        validate_type(String, 'run-on')
      end

      private def filter(unfiltered)
        unfiltered
      end
    end
  end
end
