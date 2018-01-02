require 'bolt/logger'

# Runs a command on the given set of targets and returns the result from each command execution.
#
# * This function does nothing if the list of targets is empty.
# * It is possible to run on the target 'localhost'
# * A target is a String with a targets's hostname or a Target.
# * The returned value contains information about the result per target.
#
Puppet::Functions.create_function(:run_command) do
  local_types do
    type 'TargetOrTargets = Variant[String[1], Target, Array[TargetOrTargets]]'
  end

  dispatch :run_command do
    param 'String[1]', :command
    repeated_param 'TargetOrTargets', :targets
  end

  def log_summary(object, node_count, fail_count)
    format("Ran command %s on %d node%s with %d failure%s",
           object,
           node_count,
           node_count == 1 ? '' : 's',
           fail_count,
           fail_count == 1 ? '' : 's')
  end

  def run_command(command, *targets)
    r = nil
    logger = Logger.instance
    logger.notice("Running command #{command}")
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, operation: 'run_command'
      )
    end

    executor = Puppet.lookup(:bolt_executor) { nil }
    unless executor && Puppet.features.bolt?
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_MISSING_BOLT, action: _('run a command')
      )
    end

    # Ensure that that given targets are all Target instances
    targets = targets.flatten.map { |t| t.is_a?(String) ? Bolt::Target.new(t) : t }

    if targets.empty?
      call_function('debug', "Simulating run_command('#{command}') - no targets given - no action taken")
      r = Bolt::ExecutionResult::EMPTY_RESULT
    else
      # Awaits change in the executor, enabling it receive Target instances
      hosts = targets.map(&:host)

      r = Bolt::ExecutionResult.from_bolt(executor.run_command(executor.from_uris(hosts), command))
    end
    logger.notice(log_summary(command, targets.size, r.error_nodes.count))
    r
  end
end
