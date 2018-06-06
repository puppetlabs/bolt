# frozen_string_literal: true

require 'bolt/error'

# Runs the `plan` referenced by its name passing giving arguments to it given as a hash of name to value mappings.
# A plan is autoloaded from under <root>/plans if not already defined.
#
# @example defining and running a plan
#   plan myplan($x) {
#     # do things with tasks
#     notice "plan done with param x = ${x}"
#   }
#   run_plan('myplan', { x => 'testing' })
#
Puppet::Functions.create_function(:run_plan, Puppet::Functions::InternalFunction) do
  dispatch :run_plan do
    scope_param
    param 'String', :plan_name
    optional_param 'Hash', :named_args
  end

  def run_plan(scope, plan_name, named_args = {})
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, operation: 'run_plan'
      )
    end

    executor = Puppet.lookup(:bolt_executor) { nil }
    unless executor && Puppet.features.bolt?
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_MISSING_BOLT, action: _('run a plan')
      )
    end

    params = named_args.reject { |k, _| k.start_with?('_') }

    loaders = closure_scope.compiler.loaders
    # The perspective of the environment is wanted here (for now) to not have to
    # require modules to have dependencies defined in meta data.
    loader = loaders.private_environment_loader

    # TODO: Why would we not have a private_environment_loader?
    unless loader && (func = loader.load(:plan, plan_name))
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues.issue(:UNKNOWN_PLAN) { Bolt::Error.unknown_plan(plan_name) }
      )
    end

    # TODO: Add profiling around this
    if (run_as = named_args['_run_as'])
      old_run_as = executor.run_as
      executor.run_as = run_as
    end
    result = nil
    begin
      # If the plan does not throw :return by calling the return function it's result is
      # undef/nil
      result = catch(:return) do
        func.class.dispatcher.dispatchers[0].call_by_name_with_scope(scope, params, true)
        nil
      end&.value
      # Validate the result is a PlanResult
      unless Puppet::Pops::Types::TypeParser.singleton.parse('Boltlib::PlanResult').instance?(result)
        raise Bolt::InvalidPlanResult.new(plan_name, result.to_s)
      end
      result
    rescue Puppet::PreformattedError => err
      if named_args['_catch_errors'] && err.cause.is_a?(Bolt::Error)
        result = err.cause.to_puppet_error
      else
        raise err
      end
    ensure
      if run_as
        executor.run_as = old_run_as
      end
    end

    result
  end
end
