# frozen_string_literal: true

require 'bolt/error'
require 'bolt/pal'
require 'bolt/task'
require 'bolt/pal/issues'

# Runs a given instance of a `Task` on the given set of targets and returns the result from each.
# This function does nothing if the list of targets is empty.
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:run_task) do
  # Run a task.
  # @param task_name The task to run.
  # @param targets A pattern identifying zero or more targets. See {get_targets} for accepted patterns.
  # @param args A hash of arguments to the task. Can also include additional options.
  # @option args [Boolean] _catch_errors Whether to catch raised errors.
  # @option args [String] _run_as User to run as using privilege escalation.
  # @option args [Boolean] _noop Run the task in noop mode if available.
  # @return A list of results, one entry per target.
  # @example Run a task as root
  #   run_task('facts', $targets, '_run_as' => 'root')
  dispatch :run_task do
    param 'String[1]', :task_name
    param 'Boltlib::TargetSpec', :targets
    optional_param 'Hash[String[1], Any]', :args
    return_type 'ResultSet'
  end

  # Run a task, logging the provided description.
  # @param task_name The task to run.
  # @param targets A pattern identifying zero or more targets. See {get_targets} for accepted patterns.
  # @param description A description to be output when calling this function.
  # @param args A hash of arguments to the task. Can also include additional options.
  # @option args [Boolean] _catch_errors Whether to catch raised errors.
  # @option args [String] _run_as User to run as using privilege escalation.
  # @option args [Boolean] _noop Run the task in noop mode if available.
  # @return A list of results, one entry per target.
  # @example Run a task
  #   run_task('facts', $targets, 'Gather OS facts')
  dispatch :run_task_with_description do
    param 'String[1]', :task_name
    param 'Boltlib::TargetSpec', :targets
    param 'Optional[String]', :description
    optional_param 'Hash[String[1], Any]', :args
    return_type 'ResultSet'
  end

  def run_task(task_name, targets, args = {})
    run_task_with_description(task_name, targets, nil, args)
  end

  def run_task_with_description(task_name, targets, description, args = {})
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, action: 'run_task')
    end

    options, params = args.partition { |k, _v| k.start_with?('_') }.map(&:to_h)
    options = options.transform_keys { |k| k.sub(/^_/, '').to_sym }

    executor = Puppet.lookup(:bolt_executor)
    inventory = Puppet.lookup(:bolt_inventory)

    # Bolt calls this function internally to trigger tasks from the CLI. We
    # don't want to count those invocations.
    unless options[:bolt_api_call]
      executor.report_function_call(self.class.name)
    end

    # Report bundled content, this should capture tasks run from both CLI and Plans
    executor.report_bundled_content('Task', task_name)

    # Ensure that given targets are all Target instances
    targets = inventory.get_targets(targets)

    options[:description] = description if description

    # Don't bother loading the local task definition if all targets use the 'pcp' transport.
    if !targets.empty? && targets.all? { |t| t.transport == 'pcp' }
      # create a fake task
      task = Bolt::Task.new(task_name, {}, [{ 'name' => '', 'path' => '' }])
    else
      # TODO: use the compiler injection once PUP-8237 lands
      task_signature = Puppet::Pal::ScriptCompiler.new(closure_scope.compiler).task_signature(task_name)
      if task_signature.nil?
        raise Bolt::Error.unknown_task(task_name)
      end

      task = Bolt::Task.from_task_signature(task_signature)

      # Set the default value for any params that have one and were not provided
      params = task.parameter_defaults.merge(params)

      task_signature.runnable_with?(params) do |mismatch_message|
        raise with_stack(:TYPE_MISMATCH, mismatch_message)
      end || (raise with_stack(:TYPE_MISMATCH, 'Task parameters do not match'))
    end

    unless Puppet::Pops::Types::TypeFactory.data.instance?(params)
      # generate a helpful error message about the type-mismatch between the type Data
      # and the actual type of params
      params_t = Puppet::Pops::Types::TypeCalculator.infer_set(params)
      desc = Puppet::Pops::Types::TypeMismatchDescriber.singleton.describe_mismatch(
        'Task parameters are not of type Data. run_task()',
        Puppet::Pops::Types::TypeFactory.data, params_t
      )
      raise with_stack(:TYPE_NOT_DATA, desc)
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

    # executor.noop is set when run task is called from the CLI
    # options[:noop] is set when it's called from a plan
    if executor.noop || options[:noop]
      if task.supports_noop
        params['_noop'] = true
      else
        raise with_stack(:TASK_NO_NOOP, 'Task does not support noop')
      end
    end

    if targets.empty?
      Bolt::ResultSet.new([])
    else
      result = executor.run_task(targets, task, params, options)
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
