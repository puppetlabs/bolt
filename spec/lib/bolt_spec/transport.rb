# frozen_string_literal: true

require 'bolt/config'

module BoltSpec
  module Transport
    def runner
      Bolt::TRANSPORTS[transport].new
    end

    def transport_conf
      {}
    end
  end
end
