# frozen_string_literal: true

require 'bolt/pal/issues'

# Catches errors in a given block and returns them. This will return the
# output of the block if no errors are raised. Accepts an optional list of
# error kinds to catch.
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:catch_errors) do
  # @param error_types An array of error types to catch
  # @param block The block of steps to catch errors on
  # @return If an error is raised in the block then the error will be returned,
  #         otherwise the result will be returned
  # @example Catch errors for a block
  #   catch_errors() || {
  #     run_command("whoami", $targets)
  #     run_command("adduser ryan", $targets)
  #   }
  # @example Catch parse errors for a block of code
  #   catch_errors(['bolt/parse-error']) || {
  #    run_plan('canary', $targets)
  #    run_plan('other_plan)
  #    apply($targets) || {
  #      notify { "Hello": }
  #    }
  #   }
  dispatch :catch_errors do
    optional_param 'Array[String[1]]', :error_types
    block_param 'Callable[0, 0]', :block
    return_type 'Any'
  end

  def catch_errors(error_types = nil)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
                              action: self.class.name)
    end

    executor = Puppet.lookup(:bolt_executor)
    executor.report_function_call(self.class.name)

    begin
      yield
    rescue Puppet::PreformattedError => e
      if e.cause.is_a?(Bolt::Error)
        if error_types.nil?
          e.cause.to_puppet_error
        elsif error_types.include?(e.cause.to_h['kind'])
          e.cause.to_puppet_error
        else
          raise e
        end
      else
        raise e
      end
    end
  end
end
