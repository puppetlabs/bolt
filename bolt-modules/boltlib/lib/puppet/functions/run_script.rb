# frozen_string_literal: true

# Uploads the given script to the given set of targets and returns the result of having each target execute the script.
# This function does nothing if the list of targets is empty.
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:run_script, Puppet::Functions::InternalFunction) do
  # Run a script.
  # @param script Path to a script to run on target. Can be an absolute path or a modulename/filename selector for a
  #               file in $MODULEROOT/files.
  # @param targets A pattern identifying zero or more targets. See {get_targets} for accepted patterns.
  # @param options A hash of additional options.
  # @option options [Array[String]] arguments An array of arguments to be passed to the script.
  #   Cannot be used with `pwsh_params`.
  # @option options [Hash] pwsh_params Map of named parameters to pass to a PowerShell script.
  #   Cannot be used with `arguments`.
  # @option options [Boolean] _catch_errors Whether to catch raised errors.
  # @option options [String] _run_as User to run as using privilege escalation.
  # @option options [Hash] _env_vars Map of environment variables to set.
  # @return A list of results, one entry per target.
  # @example Run a local script on Linux targets as 'root'
  #   run_script('/var/tmp/myscript', $targets, '_run_as' => 'root')
  # @example Run a module-provided script with arguments
  #   run_script('iis/setup.ps1', $target, 'arguments' => ['/u', 'Administrator'])
  # @example Pass named parameters to a PowerShell script
  #   run_script('iis/setup.ps1', $target, 'pwsh_params' => { 'User' => 'Administrator' })
  dispatch :run_script do
    scope_param
    param 'String[1]', :script
    param 'Boltlib::TargetSpec', :targets
    optional_param 'Hash[String[1], Any]', :options
    return_type 'ResultSet'
  end

  # Run a script, logging the provided description.
  # @param script Path to a script to run on target. Can be an absolute path or a modulename/filename selector for a
  #               file in $MODULEROOT/files.
  # @param targets A pattern identifying zero or more targets. See {get_targets} for accepted patterns.
  # @param description A description to be output when calling this function.
  # @param options A hash of additional options.
  # @option options [Array[String]] arguments An array of arguments to be passed to the script.
  #   Cannot be used with `pwsh_params`.
  # @option options [Hash] pwsh_params Map of named parameters to pass to a PowerShell script.
  #   Cannot be used with `arguments`.
  # @option options [Boolean] _catch_errors Whether to catch raised errors.
  # @option options [String] _run_as User to run as using privilege escalation.
  # @option options [Hash] _env_vars Map of environment variables to set.
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

  def run_script(scope, script, targets, options = {})
    run_script_with_description(scope, script, targets, nil, options)
  end

  def run_script_with_description(scope, script, targets, description = nil, options = {})
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, action: 'run_script')
    end

    if options.key?('arguments') && options.key?('pwsh_params')
      raise Bolt::ValidationError, "Cannot specify both 'arguments' and 'pwsh_params'"
    end

    if options.key?('pwsh_params') && !options['pwsh_params'].is_a?(Hash)
      raise Bolt::ValidationError, "Option 'pwsh_params' must be a hash"
    end

    if options.key?('arguments') && !options['arguments'].is_a?(Array)
      raise Bolt::ValidationError, "Option 'arguments' must be an array"
    end

    arguments = options['arguments'] || []
    pwsh_params = options['pwsh_params']
    options = options.select { |opt| opt.start_with?('_') }.transform_keys { |k| k.sub(/^_/, '').to_sym }
    options[:description] = description if description
    options[:pwsh_params] = pwsh_params if pwsh_params

    executor = Puppet.lookup(:bolt_executor)
    inventory = Puppet.lookup(:bolt_inventory)

    # Send Analytics Report
    executor.report_function_call(self.class.name)

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
    executor.report_file_source(self.class.name, script)
    # Ensure that given targets are all Target instances)
    targets = inventory.get_targets(targets)

    if targets.empty?
      Bolt::ResultSet.new([])
    else
      r = if executor.in_parallel
            require 'concurrent'
            require 'fiber'
            future = Concurrent::Future.execute do
              executor.run_script(targets,
                                  found,
                                  arguments,
                                  options,
                                  Puppet::Pops::PuppetStack.top_of_stack)
            end

            Fiber.yield('unfinished') while future.incomplete?
            future.value || future.reason
          else
            executor.run_script(targets,
                                found,
                                arguments,
                                options,
                                Puppet::Pops::PuppetStack.top_of_stack)
          end

      if !r.ok && !options[:catch_errors]
        raise Bolt::RunFailure.new(r, 'run_script', script)
      end
      r
    end
  end
end
