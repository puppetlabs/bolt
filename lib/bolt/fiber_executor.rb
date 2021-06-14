# frozen_string_literal: true

require 'bolt/logger'
require 'bolt/plan_future'

module Bolt
  class FiberExecutor
    attr_reader :active_futures, :finished_futures

    def initialize
      @logger = Bolt::Logger.logger(self)
      @id = 0
      @active_futures = []
      @finished_futures = []
    end

    # Whether there is more than one fiber running in parallel.
    #
    def in_parallel?
      active_futures.length > 1
    end

    # Creates a new Puppet scope from the current Plan scope so that variables
    # can be used inside the block and won't interact with the outer scope.
    # Then creates a new Fiber to execute the block, wraps the Fiber in a
    # Bolt::PlanFuture, and returns the Bolt::PlanFuture.
    #
    def create_future(plan_id:, scope: nil, name: nil)
      newscope = nil
      if scope
        # Save existing variables to the new scope before starting the future
        # itself so that if the plan returns before the backgrounded block
        # starts, we still have the variables.
        newscope = Puppet::Parser::Scope.new(scope.compiler)
        local = Puppet::Parser::Scope::LocalScope.new

        # Compress the current scopes into a single vars hash to add to the new scope
        scope.to_hash(true, true).each_pair { |k, v| local[k] = v }
        newscope.push_ephemerals([local])
      end

      # Create a new Fiber that will execute the provided block.
      future = Fiber.new do
        # Yield the new scope - this should be ignored by the block if
        # `newscope` is nil.
        yield newscope
      end

      # PlanFutures are assigned an ID, which is just a global incrementing
      # integer. The main plan should always have ID 0. They also have a
      # plan_id, which identifies which plan spawned them. This is used for
      # tracking which Futures to wait on when `wait()` is called without
      # arguments.
      @id += 1
      future = Bolt::PlanFuture.new(future, @id, name: name, plan_id: plan_id)
      @logger.trace("Created future #{future.name}")

      # Register the PlanFuture with the FiberExecutor to be executed
      active_futures << future
      future
    end

    # Visit each PlanFuture registered with the FiberExecutor and resume it.
    # Fibers will yield themselves back, either if they kicked off a
    # long-running process or if the current long-running process hasn't
    # completed. If the Fiber finishes after being resumed, store the result in
    # the PlanFuture and remove the PlanFuture from the FiberExecutor.
    #
    def round_robin
      active_futures.each do |future|
        # If the Fiber is still running and can be resumed, then resume it
        @logger.trace("Checking future '#{future.name}'")
        if future.alive?
          @logger.trace("Resuming future '#{future.name}'")
          future.resume
        end

        # Once we've restarted the Fiber, check to see if it's finished again
        # and cleanup if it has.
        next if future.alive?
        @logger.trace("Cleaning up future '#{future.name}'")

        # If the future errored and the main plan has already exited, log the
        # error at warn level.
        unless active_futures.map(&:id).include?(0) || future.state == "done"
          Bolt::Logger.warn('errored_futures', "Error in future '#{future.name}': #{future.value}")
        end

        # Remove the PlanFuture from the FiberExecutor.
        finished_futures.push(active_futures.delete(future))
      end

      # If the Fiber immediately returned or if the Fiber is blocking on a
      # `wait` call, Bolt should pause for long enough that something can
      # execute before checking again. This mitigates CPU
      # thrashing.
      return unless active_futures.all? { |f| %i[returned_immediately unfinished].include?(f.value) }
      @logger.trace("Nothing can be resumed. Rechecking in 0.5 seconds.")

      sleep(0.5)
    end

    # Whether all PlanFutures have finished executing, indicating that the
    # entire plan (main plan and any PlanFutures it spawned) has finished and
    # Bolt can exit.
    #
    def plan_complete?
      active_futures.empty?
    end

    def all_futures
      active_futures + finished_futures
    end

    # Get the PlanFuture object that is currently executing
    #
    def get_current_future(fiber:)
      all_futures.select { |f| f.fiber == fiber }.first
    end

    # Get the plan invocation ID for the PlanFuture that is currently executing
    #
    def get_current_plan_id(fiber:)
      get_current_future(fiber: fiber).current_plan
    end

    # Get the Future objects associated with a particular plan invocation.
    #
    def get_futures_for_plan(plan_id:)
      all_futures.select { |f| f.original_plan == plan_id }
    end

    # Block until the provided PlanFuture objects have finished, or the timeout is reached.
    #
    def wait(futures, timeout: nil, catch_errors: false, **_kwargs)
      if futures.nil?
        results = []
        plan_id = get_current_plan_id(fiber: Fiber.current)
        # Recollect the futures for this plan until all of the futures have
        # finished. This ensures that we include futures created inside of
        # futures being waited on.
        until (futures = get_futures_for_plan(plan_id: plan_id)).map(&:alive?).none?
          if futures.map(&:fiber).include?(Fiber.current)
            msg = "The wait() function cannot be called with no arguments inside a "\
                  "background block in the same plan."
            raise Bolt::Error.new(msg, 'bolt/infinite-wait')
          end
          # Wait for all the futures we know about so far before recollecting
          # Futures for the plan and waiting again
          results = wait(futures, timeout: timeout, catch_errors: catch_errors)
        end
        return results
      end

      if timeout.nil?
        Fiber.yield(:unfinished) until futures.map(&:alive?).none?
      else
        start = Time.now
        Fiber.yield(:unfinished) until (Time.now - start > timeout) || futures.map(&:alive?).none?
        # Raise an error for any futures that are still alive
        futures.each do |f|
          if f.alive?
            f.raise(Bolt::FutureTimeoutError.new(f.name, timeout))
          end
        end
      end

      results = futures.map(&:value)

      failed_indices = results.each_index.select do |i|
        results[i].is_a?(Bolt::Error)
      end

      if failed_indices.any?
        if catch_errors
          failed_indices.each { |i| results[i] = results[i].to_puppet_error }
        else
          # Do this after handling errors for simplicity and pretty printing
          raise Bolt::ParallelFailure.new(results, failed_indices)
        end
      end

      results
    end
  end
end
