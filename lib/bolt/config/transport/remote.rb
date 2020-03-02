# frozen_string_literal: true

require 'bolt/error'
require 'bolt/config/transport'

module Bolt
  class Config
    class Remote < Transport
      OPTIONS = {
        "run-on" => { type: String,
                      desc: "The proxy target that the task executes on." }
      }.freeze

      DEFAULTS = {
        "run-on" => "localhost"
      }.freeze

      private def validate
        assert_type
      end

      private def filter(unfiltered)
        unfiltered
      end
    end
  end
end
