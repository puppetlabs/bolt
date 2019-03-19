# frozen_string_literal: true

module Bolt
  class Notifier
    def initialize(executor = nil)
      # lazy-load expensive gem code
      require 'concurrent'

      @executor = executor || Concurrent::SingleThreadExecutor.new
    end

    def notify(callback, event)
      @executor.post do
        callback.call(event)
      end
    end

    def shutdown
      @executor.shutdown
      @executor.wait_for_termination
    end
  end
end
