# frozen_string_literal: true

require 'bolt/yarn'

# Map a code block onto an array, where each array element executes in parallel.
# This function is experimental.
#
# > **Note:** Not available in apply block.
Puppet::Functions.create_function(:parallelize, Puppet::Functions::InternalFunction) do
  # Map a block onto an array, where each array element executes in parallel.
  # This function is experimental.
  # @param data The array to apply the block to.
  # @return [Array] An array of PlanResult objects. Each input from the input
  #   array returns a corresponding PlanResult object.
  # @example Execute two tasks on multiple targets. Once the task finishes on one
  #   target, that target can move to the next step without waiting for the task
  #   to finish on the second target.
  # $targets = get_targets(["host1", "host2"])
  # $result = parallelize ($targets) |$t| {
  #   run_task('a', $t)
  #   run_task('b', $t)
  # }
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

    skein = data.each_with_index.map do |object, index|
      executor.create_yarn(scope, block, object, index)
    end

    result = executor.round_robin(skein)

    failed_indices = result.each_index.select do |i|
      result[i].is_a?(Bolt::Error)
    end

    # TODO: Inner catch errors block?
    if failed_indices.any?
      raise Bolt::ParallelFailure.new(result, failed_indices)
    end

    result
  end
end
