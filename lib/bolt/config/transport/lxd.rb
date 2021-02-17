# frozen_string_literal: true

require 'bolt/error'
require 'bolt/config/transport/base'

module Bolt
  class Config
    module Transport
      class LXD < Base
        OPTIONS = %w[
          cleanup
          tmpdir
        ].freeze

        DEFAULTS = {
          'cleanup' => true
        }.freeze
      end
    end
  end
end
