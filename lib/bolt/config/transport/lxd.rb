# frozen_string_literal: true

require 'bolt/error'
require 'bolt/config/transport/base'

module Bolt
  class Config
    module Transport
      class LXD < Base
        OPTIONS = %w[
          cleanup
          remote
          tmpdir
        ].freeze

        DEFAULTS = {
          'cleanup' => true,
          'remote'  => 'local'
        }.freeze
      end
    end
  end
end
