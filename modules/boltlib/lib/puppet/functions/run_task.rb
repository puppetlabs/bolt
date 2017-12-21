# Runs a given instance of a `Task` on the given set of targets and returns the result from each.
#
# * This function does nothing if the list of targets is empty.
# * It is possible to run on the target 'localhost'
# * A target is a String with a targets's hostname or a Target.
# * The returned value contains information about the result per target.
#
Puppet::Functions.create_function(:run_task) do
  local_types do
    type 'TargetOrTargets = Variant[String[1], Target, Array[TargetOrTargets]]'
  end

  dispatch :run_task do
    param 'String[1]', :task_name
    param 'TargetOrTargets', :targets
    optional_param 'Hash[String[1], Any]', :task_args
  end

  # this is used from 'bolt task run'
  dispatch :run_task_raw do
    param 'String[1]', :task_name
    param 'TargetOrTargets', :targets
    optional_param 'Hash[String[1], Any]', :task_args
    block_param
  end

  def run_task(task_name, targets, task_args = nil)
    Puppet::DataTypes::ExecutionResult.from_bolt(
      run_task_raw(task_name, targets, task_args)
    )
  end

  def run_task_raw(task_name, targets, task_args = nil, &block)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, operation: 'run_task'
      )
    end

    # TODO: use the compiler injection once PUP-8237 lands
    task_signature = Puppet::Pal::ScriptCompiler.new(closure_scope.compiler).task_signature(task_name)
    if task_signature.nil?
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::UNKNOWN_TASK, type_name: task_name
      )
    end

    executor = Puppet.lookup(:bolt_executor) { nil }
    unless executor && Puppet.features.bolt?
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_MISSING_BOLT, action: _('run a task')
      )
    end

    use_args = task_args.nil? ? {} : task_args
    task_signature.runnable_with?(use_args) do |mismatch|
      raise Puppet::ParseError, mismatch
    end || (raise Puppet::ParseError, 'Task parameters did not match')
    task = task_signature.task

    if executor.noop
      if task.supports_noop
        use_args['_noop'] = true
      else
        raise Puppet::ParseError, 'Task does not support noop'
      end
    end

    # Ensure that that given targets are all Target instances
    targets = targets.flatten.map { |t| t.is_a?(String) ? Puppet::DataTypes::Target.new(t) : t }
    if targets.empty?
      call_function('debug', "Simulating run of task #{task.name} - no targets given - no action taken")
      Puppet::Pops::EMPTY_HASH
    else
      # TODO: Awaits change in the executor, enabling it receive Target instances
      hosts = targets.map(&:host)

      # TODO: separate handling of default since it's platform specific
      input_method = task.input_method

      executor.run_task(executor.from_uris(hosts), task.executable, input_method, use_args, &block)
    end
  end
end
