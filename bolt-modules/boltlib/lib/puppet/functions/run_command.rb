# frozen_string_literal: true

require 'bolt/error'
require 'json'

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
  # @option options [Hash[String, Any]] _env_vars Map of environment variables to set
  # @return A list of results, one entry per target.
  # @example Run a command on targets
  #   run_command('hostname', $targets, '_catch_errors' => true)
  dispatch :run_command do
    param 'String[1]', :command
    param 'Boltlib::TargetSpec', :targets
    optional_param 'Hash[String[1], Any]', :options
    return_type 'ResultSet'
  end

  # Run multiple commands.
  # @param commands Commands to run on target.
  # @param targets A pattern identifying zero or more targets. See {get_targets} for accepted patterns.
  # @param options A hash of additional options.
  # @option options [Boolean] _catch_errors Whether to catch raised errors.
  # @option options [String] _run_as User to run as using privilege escalation.
  # @option options [Hash[String, Any]] _env_vars Map of environment variables to set
  # @return A list of results, one entry per target.
  # @example Run commands on targets
  #   run_command(['hostname', 'whoami'], $targets, '_catch_errors' => true)
  dispatch :run_commands do
    param 'Array', :commands
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
  # @option options [Hash[String, Any]] _env_vars Map of environment variables to set
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

  def run_commands(commands, targets, options = {})
    run_command_with_description(commands.join(' && '), targets, nil, options)
  end

  def run_command_with_description(command, targets, description = nil, options = {})
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, action: 'run_command')
    end

    options = options.transform_keys { |k| k.sub(/^_/, '').to_sym }
    options[:description] = description if description

    # Ensure env_vars is a hash and that each hash value is transformed to JSON
    # so we don't accidentally pass Ruby-style data to the target.
    if options[:env_vars]
      unless options[:env_vars].is_a?(Hash)
        raise Bolt::ValidationError, "Option 'env_vars' must be a hash"
      end

      if (bad_keys = options[:env_vars].keys.reject { |k| k.is_a?(String) }).any?
        raise Bolt::ValidationError,
              "Keys for option 'env_vars' must be strings: #{bad_keys.map(&:inspect).join(', ')}"
      end

      options[:env_vars] = options[:env_vars].transform_values do |val|
        [Array, Hash].include?(val.class) ? val.to_json : val
      end
    end

    executor = Puppet.lookup(:bolt_executor)
    inventory = Puppet.lookup(:bolt_inventory)

    # Send Analytics Report
    executor.report_function_call(self.class.name)

    # Ensure that given targets are all Target instances
    targets = inventory.get_targets(targets)

    if targets.empty?
      call_function('debug', "Simulating run_command('#{command}') - no targets given - no action taken")
      Bolt::ResultSet.new([])
    else
      file_line = Puppet::Pops::PuppetStack.top_of_stack
      r = if executor.in_parallel?
            executor.run_in_thread do
              executor.run_command(targets, command, options, file_line)
            end
          else
            executor.run_command(targets, command, options, file_line)
          end

      if !r.ok && !options[:catch_errors]
        raise Bolt::RunFailure.new(r, 'run_command', command)
      end

      r
    end
  end
end
