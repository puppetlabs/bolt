# frozen_string_literal: true

# Map a code block onto an array, where each array element executes in parallel.
# This function is experimental.
#
# > **Note:** Not available in apply block.
Puppet::Functions.create_function(:parallelize, Puppet::Functions::InternalFunction) do
  # Map a block onto an array, where each array element executes in parallel.
  # This function is experimental.
  # @param data The array to apply the block to.
  # @param block The code block to execute for each array element.
  # @return [Array] An array of PlanResult objects. Each input from the input
  #   array returns a corresponding PlanResult object.
  # @example Execute two tasks on two targets.
  #   $targets = get_targets(["host1", "host2"])
  #   $result = parallelize ($targets) |$t| {
  #     run_task('a', $t)
  #     run_task('b', $t)
  #   }
  dispatch :parallelize do
    scope_param
    param 'Array[Any]', :data
    block_param 'Callable[Any]', :block
    return_type 'Array[Boltlib::PlanResult]'
  end

  def parallelize(scope, data, &block)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, action: 'parallelize')
    end

    executor = Puppet.lookup(:bolt_executor)
    executor.report_function_call(self.class.name)

    futures = data.map do |object|
      # We're going to immediately wait for these futures, *and* don't want
      # their results to be returned as part of `wait()`, so use a 'dummy'
      # value as the plan_id. This could also be nil, though in general we want
      # to require Futures to have a plan stack so that they don't get lost.
      executor.create_future(scope: scope, plan_id: 'parallel') do |newscope|
        # Catch 'return' calls inside the block
        result = catch(:return) do
          # Add the object to the block parameters
          args = { block.parameters[0][1].to_s => object }
          # Execute the block. Individual plan steps in the block will yield
          # the Fiber if they haven't finished, so all this needs to do is run
          # the block.
          block.closure.call_by_name_with_scope(newscope, args, true)
        end

        # If we got a return from the block, get its value
        # Otherwise the result is the last line from the block
        result = result.value if result.is_a?(Puppet::Pops::Evaluator::Return)

        # Validate the result is a PlanResult
        unless Puppet::Pops::Types::TypeParser.singleton.parse('Boltlib::PlanResult').instance?(result)
          raise Bolt::InvalidParallelResult.new(result.to_s, *Puppet::Pops::PuppetStack.top_of_stack)
        end

        result
      rescue Puppet::PreformattedError => e
        if e.cause.is_a?(Bolt::Error)
          e.cause
        else
          raise e
        end
      end
    end

    # We may eventually want parallelize to accept a timeout
    executor.wait(futures)
  end
end
