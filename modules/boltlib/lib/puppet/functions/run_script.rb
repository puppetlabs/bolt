# Uploads the given script to the given set of targets and returns the result of having each target execute the script.
#
# * This function does nothing if the list of targets is empty.
# * It is possible to run on the target 'localhost'
# * A target is a String with a targets's hostname or a Target.
# * The returned value contains information about the result per target.
#
Puppet::Functions.create_function(:run_script, Puppet::Functions::InternalFunction) do
  local_types do
    type 'TargetOrTargets = Variant[String[1], Target, Array[TargetOrTargets]]'
  end

  dispatch :run_script do
    scope_param
    param 'String[1]', :script
    param 'TargetOrTargets', :targets
    optional_param 'Hash[String[1], Any]', :options
    return_type 'ExecutionResult'
  end

  def run_script(scope, script, targets, options = nil)
    options ||= {}
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, operation: 'run_script'
      )
    end

    executor = Puppet.lookup(:bolt_executor) { nil }
    unless executor && Puppet.features.bolt?
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_MISSING_BOLT, action: _('run a script')
      )
    end

    found = Puppet::Parser::Files.find_file(script, scope.compiler.environment)
    unless found && Puppet::FileSystem.exist?(found)
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::NO_SUCH_FILE_OR_DIRECTORY, file: script
      )
    end
    unless Puppet::FileSystem.file?(found)
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::NOT_A_FILE, file: script
      )
    end

    # Ensure that that given targets are all Target instances)
    targets = [targets].flatten.map { |t| t.is_a?(String) ? Bolt::Target.new(t) : t }
    if targets.empty?
      call_function('debug', "Simulating run_script of '#{found}' - no targets given - no action taken")
      r = Bolt::ExecutionResult::EMPTY_RESULT
    else
      # Awaits change in the executor, enabling it receive Target instances
      hosts = targets.map(&:host)

      r = Bolt::ExecutionResult.from_bolt(
        executor.run_script(executor.from_uris(hosts), found, options['arguments'] || [])
      )
    end

    if !r.ok && options['_abort'] != false
      raise Bolt::RunFailure.new(r, 'run_script', script)
    end
    r
  end
end
