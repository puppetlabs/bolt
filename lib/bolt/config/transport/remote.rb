# frozen_string_literal: true

require 'bolt/error'
require 'bolt/config/transport/base'

module Bolt
  class Config
    module Transport
      class Remote < Base
        # NOTE: All transport configuration options should have a corresponding schema definition
        #       in schemas/bolt-transport-definitions.json
        OPTIONS = {
          "run-on" => { type: String,
                        desc: "The proxy target that the task executes on." }
        }.freeze

        DEFAULTS = {
          "run-on" => "localhost"
        }.freeze

        private def filter(unfiltered)
          unfiltered
        end
      end
    end
  end
end
