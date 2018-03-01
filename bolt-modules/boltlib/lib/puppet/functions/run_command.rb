require 'bolt/error'

# Runs a command on the given set of targets and returns the result from each command execution.
#
# * This function does nothing if the list of targets is empty.
# * It is possible to run on the target 'localhost'
# * A target is a String with a targets's hostname or a Target.
# * The returned value contains information about the result per target.
#
Puppet::Functions.create_function(:run_command) do
  dispatch :run_command do
    param 'String[1]', :command
    param 'Boltlib::TargetSpec', :targets
    optional_param 'Hash[String[1], Any]', :options
    return_type 'ResultSet'
  end

  def run_command(command, targets, options = nil)
    options ||= {}
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, operation: 'run_command'
      )
    end

    executor = Puppet.lookup(:bolt_executor) { nil }
    inventory = Puppet.lookup(:bolt_inventory) { nil }
    unless executor && inventory && Puppet.features.bolt?
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_MISSING_BOLT, action: _('run a command')
      )
    end

    # Ensure that given targets are all Target instances
    targets = inventory.get_targets(targets)

    if targets.empty?
      call_function('debug', "Simulating run_command('#{command}') - no targets given - no action taken")
      r = Bolt::ResultSet.new([])
    else
      r = executor.run_command(targets, command, options.select { |k, _| k == '_run_as' })
    end

    if !r.ok && !options['_catch_errors']
      raise Bolt::RunFailure.new(r, 'run_command', command)
    end
    r
  end
end
