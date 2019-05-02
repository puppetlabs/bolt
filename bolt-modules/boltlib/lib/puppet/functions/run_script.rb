# frozen_string_literal: true

# Uploads the given script to the given set of targets and returns the result of having each target execute the script.
# This function does nothing if the list of targets is empty.
#
# **NOTE:** Not available in apply block
Puppet::Functions.create_function(:run_script, Puppet::Functions::InternalFunction) do
  # Run a script.
  # @param script Path to a script to run on target. May be an absolute path or a modulename/filename selector for a
  #               file in <moduleroot>/files.
  # @param targets A pattern identifying zero or more targets. See {get_targets} for accepted patterns.
  # @param options Specify an array of arguments to the 'arguments' key to be passed to the script.
  #                Additional options: '_catch_errors', '_run_as'.
  # @return A list of results, one entry per target.
  # @example Run a local script on Linux targets as 'root'
  #   run_script('/var/tmp/myscript', $targets, '_run_as' => 'root')
  # @example Run a module-provided script with arguments
  #   run_script('iis/setup.ps1', $target, 'arguments' => ['/u', 'Administrator'])
  dispatch :run_script do
    scope_param
    param 'String[1]', :script
    param 'Boltlib::TargetSpec', :targets
    optional_param 'Hash[String[1], Any]', :options
    return_type 'ResultSet'
  end

  # Run a script, logging the provided description.
  # @param script Path to a script to run on target. May be an absolute path or a modulename/filename selector for a
  #               file in <moduleroot>/files.
  # @param targets A pattern identifying zero or more targets. See {get_targets} for accepted patterns.
  # @param description A description to be output when calling this function.
  # @param options Specify an array of arguments to the 'arguments' key to be passed to the script.
  #                Additional options: '_catch_errors', '_run_as'.
  # @return A list of results, one entry per target.
  # @example Run a script
  #   run_script('/var/tmp/myscript', $targets, 'Downloading my application')
  dispatch :run_script_with_description do
    scope_param
    param 'String[1]', :script
    param 'Boltlib::TargetSpec', :targets
    param 'String', :description
    optional_param 'Hash[String[1], Any]', :options
    return_type 'ResultSet'
  end

  def run_script(scope, script, targets, options = nil)
    run_script_with_description(scope, script, targets, nil, options)
  end

  def run_script_with_description(scope, script, targets, description = nil, options = nil)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, action: 'run_script')
    end

    options ||= {}
    options = options.merge('_description' => description) if description
    executor = Puppet.lookup(:bolt_executor) { nil }
    inventory = Puppet.lookup(:bolt_inventory) { nil }

    executor.report_function_call('run_script')

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

    # Ensure that given targets are all Target instances)
    targets = inventory.get_targets(targets)

    r = if targets.empty?
          Bolt::ResultSet.new([])
        else
          executor.run_script(targets, found, options['arguments'] || [], options.reject { |k, _| k == 'arguments' })
        end

    if !r.ok && !options['_catch_errors']
      raise Bolt::RunFailure.new(r, 'run_script', script)
    end
    r
  end
end
