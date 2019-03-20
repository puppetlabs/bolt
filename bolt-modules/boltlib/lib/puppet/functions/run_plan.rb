# frozen_string_literal: true

require 'bolt/error'

# Runs the `plan` referenced by its name. A plan is autoloaded from `<moduleroot>/plans`.
#
# **NOTE:** Not available in apply block
Puppet::Functions.create_function(:run_plan, Puppet::Functions::InternalFunction) do
  # @param plan_name The plan to run.
  # @param named_args Arguments to the plan. Can also include additional options: '_catch_errors', '_run_as'.
  # @return [PlanResult] The result of running the plan. Undef if plan does not explicitly return results.
  # @example Run a plan
  #   run_plan('canary', 'command' => 'false', 'nodes' => $targets, '_catch_errors' => true)
  dispatch :run_plan do
    scope_param
    param 'String', :plan_name
    optional_param 'Hash', :named_args
    return_type 'Boltlib::PlanResult'
  end

  def run_plan(scope, plan_name, named_args = {})
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, action: 'run_plan')
    end

    executor = Puppet.lookup(:bolt_executor) { nil }
    unless executor && Puppet.features.bolt?
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_MISSING_BOLT, action: _('run a plan')
      )
    end

    # Bolt calls this function internally to trigger plans from the CLI. We
    # don't want to count those invocations.
    unless named_args['_bolt_api_call']
      executor.report_function_call('run_plan')
    end

    # Report bundled content, this should capture plans run from both CLI and Plans
    executor.report_bundled_content('Plan', plan_name)

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

    if (run_as = named_args['_run_as'])
      old_run_as = executor.run_as
      executor.run_as = run_as
    end

    # wrap plan execution in logging messages
    executor.log_plan(plan_name) do
      result = nil
      begin
        # If the plan does not throw :return by calling the return function it's result is
        # undef/nil
        result = catch(:return) do
          scope.with_global_scope do |global_scope|
            func.class.dispatcher.dispatchers[0].call_by_name_with_scope(global_scope, params, true)
          end
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
end
