# frozen_string_literal: true

require 'fiber'

module Bolt
  class PlanFuture
    attr_reader :fiber, :id
    attr_accessor :value

    def initialize(fiber, id, name = nil)
      @fiber = fiber
      @id    = id
      @name  = name
      @value = nil
    end

    def name
      @name || @id
    end

    def to_s
      "Future '#{name}'"
    end

    def alive?
      fiber.alive?
    end

    def raise(exception)
      # Make sure the value gets set
      @value = exception
      # This was introduced in Ruby 2.7
      begin
        # Raise an exception to kill the Fiber. If the Fiber has not been
        # resumed yet, or is already terminated this will raise a FiberError.
        # We don't especially care about the FiberError, as long as the Fiber
        # doesn't report itself as alive.
        fiber.raise(exception)
      rescue FiberError
        # If the Fiber is still alive, resume it with a block to raise the
        # exception which will terminate it.
        if fiber.alive?
          fiber.resume { raise(exception) }
        end
      end
    end

    def resume
      if fiber.alive?
        @value = fiber.resume
      else
        @value
      end
    end

    def state
      if fiber.alive?
        "running"
      elsif value.is_a?(Exception)
        "error"
      else
        "done"
      end
    end
  end
end
