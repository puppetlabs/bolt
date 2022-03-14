# frozen_string_literal: true

require_relative '../../../bolt/error'
require_relative '../../../bolt/config/transport/base'

module Bolt
  class Config
    module Transport
      class LXD < Base
        OPTIONS = %w[
          cleanup
          remote
          tmpdir
        ].concat(RUN_AS_OPTIONS).sort.freeze

        DEFAULTS = {
          'cleanup' => true,
          'remote'  => 'local'
        }.freeze
      end
    end
  end
end
