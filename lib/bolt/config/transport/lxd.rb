# frozen_string_literal: true

require 'bolt/error'
require 'bolt/config/transport/base'

module Bolt
  class Config
    module Transport
      class LXD < Base
        # targets:
        # - name: container1
        #   uri: 159.89.184.173
        #   config:
        #     transport: lxd
        #     lxd:
        #       remote: remote1
        # - name: container2
        #   uri: 10.108.0.7
        #   config:
        #     transport: lxd
        #     lxd:
        #       remote: remote2

        OPTIONS = %w[
          remote
        ].freeze

        # remotes are set in the local environment with
        #
        #   lxc remote switch remote1
        #
        # How do we just respect this default? Do we need anything in this object?
        DEFAULTS = {

        }.freeze

        private def validate
          puts 'how in the world!!!?!?!?'
          super
          # TODO
        end
      end
    end
  end
end
