# frozen_string_literal: true

require 'bolt/error'
require 'bolt/pal'
require 'bolt/task'

# Runs a given instance of a `Task` with target-specific parameters on the given set of targets and
# returns the result from each. This function differs from {run_task} by accepting a block that returns
# a `Hash` of target-specific parameters that are passed to the task. This can be used to send parameters
# based on a target's attributes, such as its `facts`, or to use conditional logic to determine the
# parameters a task should receive for a specific target.
#
# This function does nothing if the list of targets is empty.
#
# > **Note:** Not available in apply block
#
# > **Note:** Not available to targets using the pcp transport
Puppet::Functions.create_function(:run_task_with) do
  # Run a task with target-specific parameters.
  # @param task_name The task to run.
  # @param targets A pattern identifying zero or more targets. See {get_targets} for accepted patterns.
  # @param options A hash of additional options.
  # @option options [Boolean] _catch_errors Whether to catch raised errors.
  # @option options [Boolean] _noop Run the task in noop mode if available.
  # @option options [String] _run_as User to run as using privilege escalation.
  # @param block A block that returns a `Hash` of target-specific parameters for the task.
  # @return A list of results, one entry per target.
  # @example Run a task with target-specific parameters as root
  #   run_task_with('my_task', $targets, '_run_as' => 'root') |$t| {
  #     { 'param1' => $t.vars['var1'],
  #       'param2' => $t.vars['var2'] }
  #   }
  dispatch :run_task_with do
    param 'String[1]', :task_name
    param 'Boltlib::TargetSpec', :targets
    optional_param 'Hash[String[1], Any]', :options
    required_block_param 'Callable[Target]', :block
    return_type 'ResultSet'
  end

  # Run a task with target-specific parameters, logging the provided description.
  # @param task_name The task to run.
  # @param targets A pattern identifying zero or more targets. See {get_targets} for accepted patterns.
  # @param description A description to be output when calling this function.
  # @param options A hash of additional options.
  # @option options [Boolean] _catch_errors Whether to catch raised errors.
  # @option options [Boolean] _noop Run the task in noop mode if available.
  # @option options [String] _run_as User to run as using privilege escalation.
  # @param block A block that returns a `Hash` of target-specific parameters for the task.
  # @return A list of results, one entry per target.
  # @example Run a task with target-specific parameters and a description
  #   run_task_with('my_task', $targets, 'Update system packages') |$t| {
  #     { 'param1' => $t.vars['var1'],
  #       'param2' => $t.vars['var2'] }
  #   }
  dispatch :run_task_with_with_description do
    param 'String[1]', :task_name
    param 'Boltlib::TargetSpec', :targets
    param 'Optional[String]', :description
    optional_param 'Hash[String[1], Any]', :options
    required_block_param 'Callable[Target]', :block
    return_type 'ResultSet'
  end

  def run_task_with(task_name, targets, options = {}, &block)
    run_task_with_with_description(task_name, targets, nil, options, &block)
  end

  def run_task_with_with_description(task_name, targets, description, options = {})
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(
          Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
          action: 'run_task_with'
        )
    end

    executor  = Puppet.lookup(:bolt_executor)
    inventory = Puppet.lookup(:bolt_inventory)
    error_set = []

    # Report to analytics
    executor.report_function_call(self.class.name)
    executor.report_bundled_content('Task', task_name)

    # Keep valid metaparameters, discarding everything else
    options = options.select { |k, _v| k.start_with?('_') }
                     .transform_keys { |k| k.sub(/^_/, '').to_sym }

    options[:description] = description if description

    # Get all the targets
    targets = Array(inventory.get_targets(targets))

    # If all targets use the 'pcp' transport, use a fake task instead of loading the local definition
    # Otherwise, load the local task definition
    if (pcp_only = targets.any? && targets.all? { |t| t.transport == 'pcp' })
      task = Bolt::Task.new(task_name, {}, [{ 'name' => '', 'path' => '' }])
    else
      task_signature = Puppet::Pal::ScriptCompiler.new(closure_scope.compiler).task_signature(task_name)

      if task_signature.nil?
        raise Bolt::Error.unknown_task(task_name)
      end

      task = Bolt::Task.from_task_signature(task_signature)
    end

    # Map the targets to their specific parameters and merge with the defaults
    target_mapping = targets.each_with_object({}) do |target, mapping|
      params = yield(target)

      # Parameters returned from the block should be a Hash. If they're not, create a failing
      # Result for the target that will later be added to the ResultSet.
      unless params.is_a?(Hash)
        exception = with_stack(
          :TYPE_MISMATCH,
          "Block must return a Hash of parameters, received #{params.class}"
        )
        error_set << Bolt::Result.from_exception(target, exception, action: 'task')
        next
      end

      # If parameters are mismatched, create a failing result for the target that will later
      # be added to the ResultSet.
      unless pcp_only
        # Set the default value for any params that have one and were not provided or are undef
        params = task.parameter_defaults.merge(params) do |_, default, passed|
          passed.nil? ? default : passed
        end

        type_match = task_signature.runnable_with?(params) do |mismatch_message|
          exception = with_stack(:TYPE_MISMATCH, mismatch_message)
          error_set << Bolt::Result.from_exception(target, exception, action: 'task')
        end

        next unless type_match
      end

      # If there is a type mismatch between the type Data and the type of the params, create
      # a failing result for the target that will later be added to the ResultSet.
      unless Puppet::Pops::Types::TypeFactory.data.instance?(params)
        params_t = Puppet::Pops::Types::TypeCalculator.infer_set(params)
        desc = Puppet::Pops::Types::TypeMismatchDescriber.singleton.describe_mismatch(
          'Task parameters are not of type Data. run_task_with()',
          Puppet::Pops::Types::TypeFactory.data, params_t
        )
        exception = with_stack(:TYPE_NOT_DATA, desc)
        error_set << Bolt::Result.from_exception(target, exception, action: 'task')
        next
      end

      # Wrap parameters marked with '"sensitive": true' in the task metadata with a
      # Sensitive wrapper type. This way it's not shown in logs.
      if (param_spec = task.parameters)
        params.each do |k, v|
          if param_spec[k] && param_spec[k]['sensitive']
            params[k] = Puppet::Pops::Types::PSensitiveType::Sensitive.new(v)
          end
        end
      end

      # Set the default value for any params that have one and were not provided or are undef
      mapping[target] = task.parameter_defaults.merge(params) do |_, default, passed|
        passed.nil? ? default : passed
      end
    end

    # Add a noop parameter if the function was called with the noop metaparameter.
    if options[:noop]
      if task.supports_noop
        target_mapping.each_value { |params| params['_noop'] = true }
      else
        raise with_stack(:TASK_NO_NOOP, 'Task does not support noop')
      end
    end

    if targets.empty?
      Bolt::ResultSet.new([])
    else
      # Combine the results from the task run with any failing results that were
      # generated earlier when creating the target mapping
      task_result = if executor.in_parallel
                      require 'concurrent'
                      require 'fiber'
                      future = Concurrent::Future.execute do
                        executor.run_task_with(target_mapping,
                                               task,
                                               options,
                                               Puppet::Pops::PuppetStack.top_of_stack)
                      end

                      Fiber.yield('unfinished') while future.incomplete?
                      future.value || future.reason
                    else
                      executor.run_task_with(target_mapping,
                                             task,
                                             options,
                                             Puppet::Pops::PuppetStack.top_of_stack)
                    end
      result = Bolt::ResultSet.new(task_result.results + error_set)

      if !result.ok && !options[:catch_errors]
        raise Bolt::RunFailure.new(result, 'run_task', task_name)
      end

      result
    end
  end

  def with_stack(kind, msg)
    issue = Puppet::Pops::Issues.issue(kind) { msg }
    Puppet::ParseErrorWithIssue.from_issue_and_stack(issue)
  end
end
