# frozen_string_literal: true

require 'bolt/error'

# Runs a given instance of a `Task` on the given set of targets and returns the result from each.
# This function does nothing if the list of targets is empty.
Puppet::Functions.create_function(:run_task) do
  # Run a task.
  # @param task_name The task to run.
  # @param targets A pattern identifying zero or more targets. See {get_targets} for accepted patterns.
  # @param task_args Arguments to the plan. Can also include additional options: '_catch_errors', '_run_as'.
  # @return A list of results, one entry per target.
  # @example Run a task as root
  #   run_task('facts', $targets, '_run_as' => 'root')
  dispatch :run_task do
    param 'String[1]', :task_name
    param 'Boltlib::TargetSpec', :targets
    optional_param 'Hash[String[1], Any]', :task_args
    return_type 'ResultSet'
  end

  # Run a task, logging the provided description.
  # @param task_name The task to run.
  # @param targets A pattern identifying zero or more targets. See {get_targets} for accepted patterns.
  # @param description A description to be output when calling this function.
  # @param task_args Arguments to the plan. Can also include additional options: '_catch_errors', '_run_as'.
  # @return A list of results, one entry per target.
  # @example Run a task
  #   run_task('facts', $targets, 'Gather OS facts')
  dispatch :run_task_with_description do
    param 'String[1]', :task_name
    param 'Boltlib::TargetSpec', :targets
    param 'String', :description
    optional_param 'Hash[String[1], Any]', :task_args
    return_type 'ResultSet'
  end

  # Run a task, calling the block as each node starts and finishes execution. This is used from 'bolt task run'
  # @param task_name The task to run.
  # @param targets A pattern identifying zero or more targets. See {get_targets} for accepted patterns.
  # @param description A description to be output when calling this function.
  # @param task_args Arguments to the plan. Can also include additional options: '_catch_errors', '_run_as'.
  # @param block A block that's invoked as actions are started and finished on each node.
  # @return A list of results, one entry per target.
  dispatch :run_task_raw do
    param 'String[1]', :task_name
    param 'Boltlib::TargetSpec', :targets
    param 'Optional[String]', :description
    optional_param 'Hash[String[1], Any]', :task_args
    block_param 'Callable[Struct[{type => Enum[node_start, node_result], target => Target}], 1, 1]', :block
    return_type 'ResultSet'
  end

  def run_task(task_name, targets, task_args = nil)
    run_task_with_description(task_name, targets, nil, task_args)
  end

  def run_task_with_description(task_name, targets, description, task_args = nil)
    task_args ||= {}
    r = run_task_raw(task_name, targets, description, task_args)
    if !r.ok && !task_args['_catch_errors']
      raise Bolt::RunFailure.new(r, 'run_task', task_name)
    end
    r
  end

  def run_task_raw(task_name, targets, description = nil, task_args = nil, &block)
    task_args ||= {}
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, operation: 'run_task'
      )
    end

    executor = Puppet.lookup(:bolt_executor) { nil }
    inventory = Puppet.lookup(:bolt_inventory) { nil }
    unless executor && inventory && Puppet.features.bolt?
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_MISSING_BOLT, action: _('run a task')
      )
    end

    # Bolt calls this function internally to trigger tasks from the CLI. We
    # don't want to count those invocations.
    unless task_args['_bolt_api_call']
      executor.report_function_call('run_task')
    end

    # Report bundled content, this should capture tasks run from both CLI and Plans
    executor.report_bundled_content('Task', task_name)

    # Ensure that given targets are all Target instances
    targets = inventory.get_targets(targets)

    options, use_args = task_args.partition { |k, _| k.start_with?('_') }.map(&:to_h)

    options['_description'] = description if description

    # Don't bother loading the local task definition if all targets use the 'pcp' transport
    # and the local-validation option is set to false for all of them
    if !targets.empty? && targets.all? { |t| t.protocol == 'pcp' && t.options['local-validation'] == false }
      # create a fake task
      task = Puppet::Pops::Types::TypeFactory.task.from_hash(
        'name'            => task_name,
        'implementations' => [{ 'name' => '', 'path' => '' }],
        'supports_noop'   => true
      )
    else
      # TODO: use the compiler injection once PUP-8237 lands
      task_signature = Puppet::Pal::ScriptCompiler.new(closure_scope.compiler).task_signature(task_name)
      if task_signature.nil?
        raise with_stack(:UNKNOWN_TASK, Bolt::Error.unknown_task(task_name))
      end

      task_signature.runnable_with?(use_args) do |mismatch_message|
        raise with_stack(:TYPE_MISMATCH, mismatch_message)
      end || (raise with_stack(:TYPE_MISMATCH, 'Task parameters do not match'))

      task = task_signature.task
    end

    unless Puppet::Pops::Types::TypeFactory.data.instance?(use_args)
      raise with_stack(:TYPE_NOT_DATA, 'Task parameters is not of type Data')
    end

    if executor.noop
      if task.supports_noop
        use_args['_noop'] = true
      else
        raise with_stack(:TASK_NO_NOOP, 'Task does not support noop')
      end
    end

    if targets.empty?
      Bolt::ResultSet.new([])
    else
      executor.run_task(targets, task, use_args, options, &block)
    end
  end

  def with_stack(kind, msg)
    issue = Puppet::Pops::Issues.issue(kind) { msg }
    Puppet::ParseErrorWithIssue.from_issue_and_stack(issue)
  end
end
