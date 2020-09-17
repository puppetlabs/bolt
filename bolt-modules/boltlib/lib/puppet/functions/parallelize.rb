# frozen_string_literal: true

require 'bolt/yarn'

# Map a code bock onto an array, where each array element executes in parallel.
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
      fiber = Fiber.new do
        # Create the new scope
        newscope = Puppet::Parser::Scope.new(scope.compiler)
        local = Puppet::Parser::Scope::LocalScope.new

        # Compress the current scopes into a single vars hash to add to the new scope
        current_scope = scope.effective_symtable(true)
        until current_scope.nil?
          current_scope.instance_variable_get(:@symbols)&.each_pair { |k, v| local[k] = v }
          current_scope = current_scope.parent
        end
        newscope.push_ephemerals([local])

        begin
          result = catch(:return) do
            args = { block.parameters[0][1].to_s => object }
            block.closure.call_by_name_with_scope(newscope, args, true)
          end

          # If we got a return from the block, get it's value
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

      Bolt::Yarn.new(fiber, index)
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
