require 'concurrent'

module Bolt
  class Notifier
    def initialize(executor = Concurrent::SingleThreadExecutor.new)
      @executor = executor
    end

    def notify(callback, target, result)
      @executor.post do
        callback.call(target, result)
      end
    end

    def shutdown
      @executor.shutdown
      @executor.wait_for_termination
    end
  end
end
