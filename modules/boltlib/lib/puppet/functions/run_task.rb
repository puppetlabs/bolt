# Runs a given instance of a `Task` on the given set of targets and returns the result from each.
#
# * This function does nothing if the list of targets is empty.
# * It is possible to run on the target 'localhost'
# * A target is a String with a targets's hostname or a Target.
# * The returned value contains information about the result per target.
#
require 'bolt/error'

Puppet::Functions.create_function(:run_task) do
  dispatch :run_task do
    param 'String[1]', :task_name
    param 'Boltlib::TargetSpec', :targets
    optional_param 'Hash[String[1], Any]', :task_args
    return_type 'ResultSet'
  end

  # this is used from 'bolt task run'
  dispatch :run_task_raw do
    param 'String[1]', :task_name
    param 'Boltlib::TargetSpec', :targets
    optional_param 'Hash[String[1], Any]', :task_args
    # return_type 'ResultSet'
    block_param
  end

  def run_task(task_name, targets, task_args = nil)
    task_args ||= {}
    r = run_task_raw(task_name, targets, task_args)
    if !r.ok && !task_args['_catch_errors']
      raise Bolt::RunFailure.new(r, 'run_task', task_name)
    end
    r
  end

  def run_task_raw(task_name, targets, task_args = nil, &block)
    task_args ||= {}
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, operation: 'run_task'
      )
    end

    # TODO: use the compiler injection once PUP-8237 lands
    task_signature = Puppet::Pal::ScriptCompiler.new(closure_scope.compiler).task_signature(task_name)
    if task_signature.nil?
      raise with_stack(:UNKNOWN_TASK, Bolt::Error.unknown_task(task_name))
    end

    executor = Puppet.lookup(:bolt_executor) { nil }
    inventory = Puppet.lookup(:bolt_inventory) { nil }
    unless executor && inventory && Puppet.features.bolt?
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_MISSING_BOLT, action: _('run a task')
      )
    end

    use_args = task_args.reject { |k, _| k.start_with?('_') }

    task_signature.runnable_with?(use_args) do |mismatch_message|
      raise with_stack(:TYPE_MISMATCH, mismatch_message)
    end || (raise with_stack(:TYPE_MISMATCH, 'Task parameters do not match'))

    unless Puppet::Pops::Types::TypeFactory.data.instance?(use_args)
      raise with_stack(:TYPE_NOT_DATA, 'Task parameters is not of type Data')
    end

    task = task_signature.task

    if executor.noop
      if task.supports_noop
        use_args['_noop'] = true
      else
        raise with_stack(:TASK_NO_NOOP, 'Task does not support noop')
      end
    end

    # Ensure that given targets are all Target instances
    targets = inventory.get_targets(targets)
    if targets.empty?
      Bolt::ResultSet.new([])
    else
      options = task_args.select { |k, _| k == '_run_as' }
      executor.run_task(targets, task, use_args, options, &block)
    end
  end

  def with_stack(kind, msg)
    issue = Puppet::Pops::Issues.issue(kind) { msg }
    Puppet::ParseErrorWithIssue.from_issue_and_stack(issue)
  end
end
