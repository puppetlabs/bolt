require 'bolt/error'

# Raises a Bolt::PlanFailure exception to signal to callers that the plan failed
#
# Plan authors should call this function when their plan is not successful. The
# error may then be caught by another plans run_plan function or in bolt itself
Puppet::Functions.create_function(:fail_plan) do
  dispatch :from_args do
    param 'String[1]', :msg
    optional_param 'String[1]', :kind
    optional_param 'Hash[String[1], Any]', :details
    optional_param 'String[1]', :issue_code
  end

  dispatch :from_error do
    param 'Error', :error
  end

  def from_args(msg, kind = nil, details = nil, issue_code = nil)
    raise Bolt::PlanFailure.new(msg, kind || 'bolt/plan-failure', details, issue_code)
  end

  def from_error(e)
    from_args(e.message, e.kind, e.details, e.issue_code)
  end
end
