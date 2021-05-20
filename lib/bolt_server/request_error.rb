# frozen_string_literal: true

require 'bolt/error'

module BoltServer
  class RequestError < Bolt::Error
    def initialize(msg, details = {})
      super(msg, 'bolt-server/request-error', details)
    end
  end
end
