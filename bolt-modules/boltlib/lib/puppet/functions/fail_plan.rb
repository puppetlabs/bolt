# frozen_string_literal: true

require 'bolt/error'

# Raises a `Bolt::PlanFailure` exception to signal to callers that the plan failed.
#
# Plan authors should call this function when their plan is not successful. The
# error may then be caught by another plans `run_plan` function or in Bolt itself
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:fail_plan) do
  # Fail a plan, generating an exception from the parameters.
  # @param msg An error message.
  # @param kind An easily matchable error kind.
  # @param details Machine-parseable details about the error.
  # @param issue_code Unused.
  # @return Raises an exception.
  # @example Raise an exception
  #   fail_plan('We goofed up', 'task-unexpected-result', { 'result' => 'null' })
  dispatch :from_args do
    param 'String[1]', :msg
    optional_param 'String[1]', :kind
    optional_param 'Hash[String[1], Any]', :details
    optional_param 'String[1]', :issue_code
  end

  # Fail a plan, generating an exception from an existing Error object.
  # @param error An error object.
  # @return Raises an exception.
  # @example Raise an exception
  #   fail_plan(Error('We goofed up', 'task-unexpected-result', { 'result' => 'null' }))
  dispatch :from_error do
    param 'Error', :error
  end

  def from_args(msg, kind = nil, details = nil, issue_code = nil)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, action: 'fail_plan')
    end
  
    executor = Puppet.lookup(:bolt_executor)
    # Send Analytics Report
    executor.report_function_call(self.class.name)
  
    # Process details to safely handle any Error objects within it
    if details && details.is_a?(Hash)
      sanitized_details = {}
      details.each do |k, v|
        # Handle both Bolt::Error and Puppet::DataTypes::Error objects
        if v.is_a?(Puppet::DataTypes::Error) || v.is_a?(Bolt::Error)
          # For Error objects, only include basic properties to prevent recursion
          # Extract only essential information, avoiding any details hash
          error_hash = {
            'kind' => v.respond_to?(:kind) ? v.kind : nil,
            'msg' => v.respond_to?(:msg) ? v.msg : v.message
          }
          # Add issue_code if it exists
          error_hash['issue_code'] = v.issue_code if v.respond_to?(:issue_code) && v.issue_code
          
          # Clean up nil values
          error_hash.compact!
          
          sanitized_details[k] = error_hash
        else
          sanitized_details[k] = v
        end
      end
      details = sanitized_details
    end
  
    raise Bolt::PlanFailure.new(msg, kind || 'bolt/plan-failure', details, issue_code)
  end

  def from_error(err)
    # Extract just the basic properties
    msg = err.message
    kind = err.kind
    issue_code = err.issue_code
    
    # Intentionally NOT passing err.details to avoid circular references
    from_args(msg, kind, nil, issue_code)
  end
end
