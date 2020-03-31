# frozen_string_literal: true

require 'bolt/error'
require 'bolt/pal/issues'

# Runs a command on the given set of targets and returns the result from each command execution.
# This function does nothing if the list of targets is empty.
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:run_command) do
  # Run a command.
  # @param command A command to run on target.
  # @param targets A pattern identifying zero or more targets. See {get_targets} for accepted patterns.
  # @param options A hash of additional options.
  # @option options [Boolean] _catch_errors Whether to catch raised errors.
  # @option options [String] _run_as User to run as using privilege escalation.
  # @return A list of results, one entry per target.
  # @example Run a command on targets
  #   run_command('hostname', $targets, '_catch_errors' => true)
  dispatch :run_command do
    param 'String[1]', :command
    param 'Boltlib::TargetSpec', :targets
    optional_param 'Hash[String[1], Any]', :options
    return_type 'ResultSet'
  end

  # Run a command, logging the provided description.
  # @param command A command to run on target.
  # @param targets A pattern identifying zero or more targets. See {get_targets} for accepted patterns.
  # @param description A description to be output when calling this function.
  # @param options A hash of additional options.
  # @option options [Boolean] _catch_errors Whether to catch raised errors.
  # @option options [String] _run_as User to run as using privilege escalation.
  # @return A list of results, one entry per target.
  # @example Run a command on targets
  #   run_command('hostname', $targets, 'Get hostname')
  dispatch :run_command_with_description do
    param 'String[1]', :command
    param 'Boltlib::TargetSpec', :targets
    param 'String', :description
    optional_param 'Hash[String[1], Any]', :options
    return_type 'ResultSet'
  end

  def run_command(command, targets, options = {})
    run_command_with_description(command, targets, nil, options)
  end

  def run_command_with_description(command, targets, description = nil, options = {})
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, action: 'run_command')
    end

    options = options.transform_keys { |k| k.sub(/^_/, '').to_sym }
    options[:description] = description if description

    executor = Puppet.lookup(:bolt_executor)
    inventory = Puppet.lookup(:bolt_inventory)

    executor.report_function_call(self.class.name)

    # Ensure that given targets are all Target instances
    targets = inventory.get_targets(targets)

    if targets.empty?
      call_function('debug', "Simulating run_command('#{command}') - no targets given - no action taken")
      r = Bolt::ResultSet.new([])
    else
      r = executor.run_command(targets, command, options)
    end

    if !r.ok && !options[:catch_errors]
      raise Bolt::RunFailure.new(r, 'run_command', command)
    end
    r
  end
end
