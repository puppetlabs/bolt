# frozen_string_literal: true

require 'bolt/error'
require 'bolt/config/transport/base'

module Bolt
  class Config
    module Transport
      class Remote < Base
        OPTIONS = %w[
          run-on
        ].freeze

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
