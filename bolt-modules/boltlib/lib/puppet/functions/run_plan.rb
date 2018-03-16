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
    if loader && (func = loader.load(:plan, plan_name))
      # TODO: Add profiling around this
      if (run_as = named_args['_run_as'])
        old_run_as = executor.run_as
        executor.run_as = run_as
      end

      begin
        result = func.class.dispatcher.dispatchers[0].call_by_name_with_scope(scope, params, true)
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

      return result
    end

    # Could not find plan
    raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
      Puppet::Pops::Issues.issue(:UNKNOWN_PLAN) { Bolt::Error.unknown_plan(plan_name) }
    )
  end
end
