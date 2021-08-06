# frozen_string_literal: true

require 'fiber'

module Bolt
  class PlanFuture
    attr_reader :fiber, :id, :scope
    attr_accessor :value, :plan_stack

    def initialize(fiber, id, plan_id:, name: nil, scope: nil)
      @fiber = fiber
      @id    = id
      @name  = name
      @value = nil

      # Default to Puppet's current global_scope, otherwise things will
      # blow up when the Fiber Executor tries to override the global_scope.
      @scope = scope || Puppet.lookup(:global_scope) { nil }

      # The plan invocation ID when the Future is created may be
      # different from the plan ID of the Future when we switch to it if a new
      # plan was run inside the Future, so keep track of the plans that a
      # Future is executing in as a stack. When one plan finishes, pop it off
      # since now we're in the calling plan. These IDs are unique to each plan
      # invocation, not just plan names.
      @plan_stack = [plan_id]
    end

    def original_plan
      @plan_stack.last
    end

    def current_plan
      @plan_stack.first
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
