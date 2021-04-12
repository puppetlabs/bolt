# frozen_string_literal: true

# Starts a block of code in parallel with the main plan without blocking.
# Returns a Future object.
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:background, Puppet::Functions::InternalFunction) do
  # Starts a block of code in parallel with the main plan without blocking.
  # Returns a Future object.
  # @param name An optional name for legible logs.
  # @param block The code block to run in the background.
  # @return A Bolt Future object
  # @example Start a long-running process
  #   background() || {
  #     run_task('superlong::task', $targets)
  #   }
  #   run_command("echo 'Continue immediately'", $targets)
  dispatch :background do
    scope_param
    optional_param 'String[1]', :name
    block_param 'Callable[0, 0]', :block
    return_type 'Future'
  end

  def background(scope, name = nil, &block)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, action: 'background')
    end

    executor = Puppet.lookup(:bolt_executor)
    executor.report_function_call(self.class.name)

    executor.create_future(scope: scope, name: name) do |newscope|
      # Catch 'return' calls inside the block
      result = catch(:return) do
        # Execute the block. Individual plan steps in the block will yield
        # the Fiber if they haven't finished, so all this needs to do is run
        # the block.
        block.closure.call_by_name_with_scope(newscope, {}, true)
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
end
