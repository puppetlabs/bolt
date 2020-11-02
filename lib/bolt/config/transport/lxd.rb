# frozen_string_literal: true

require 'bolt/error'
require 'bolt/config/transport/base'

module Bolt
  class Config
    module Transport
      class LXD < Base
        OPTIONS = %w[
          
        ].freeze

        DEFAULTS = {

        }.freeze

        #private def validate
        #  super
        #  # TODO
        #end
      end
    end
  end
end