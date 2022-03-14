# frozen_string_literal: true

require 'bolt/error'

# Uploads the given file or directory to the given set of targets and returns the result from each upload.
# This function does nothing if the list of targets is empty.
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:upload_file, Puppet::Functions::InternalFunction) do
  # Upload a file or directory.
  # @param source A source path, either an absolute path or a modulename/filename selector for a
  #               file or directory in $MODULEROOT/files.
  # @param destination An absolute path on the target(s).
  # @param targets A pattern identifying zero or more targets. See {get_targets} for accepted patterns.
  # @param options A hash of additional options.
  # @option options [Boolean] _catch_errors Whether to catch raised errors.
  # @option options [String] _run_as User to run as using privilege escalation.
  # @return A list of results, one entry per target.
  # @example Upload a local file to Linux targets and change owner to 'root'
  #   upload_file('/var/tmp/payload.tgz', '/tmp/payload.tgz', $targets, '_run_as' => 'root')
  # @example Upload a module file to a Windows target
  #   upload_file('postgres/default.conf', 'C:/ProgramData/postgres/default.conf', $target)
  dispatch :upload_file do
    scope_param
    param 'String[1]', :source
    param 'String[1]', :destination
    param 'Boltlib::TargetSpec', :targets
    optional_param 'Hash[String[1], Any]', :options
    return_type 'ResultSet'
  end

  # Upload a file or directory, logging the provided description.
  # @param source A source path, either an absolute path or a modulename/filename selector for a
  #               file or directory in $MODULEROOT/files.
  # @param destination An absolute path on the target(s).
  # @param targets A pattern identifying zero or more targets. See {get_targets} for accepted patterns.
  # @param description A description to be output when calling this function.
  # @param options A hash of additional options.
  # @option options [Boolean] _catch_errors Whether to catch raised errors.
  # @option options [String] _run_as User to run as using privilege escalation.
  # @return A list of results, one entry per target.
  # @example Upload a file
  #   upload_file('/var/tmp/payload.tgz', '/tmp/payload.tgz', $targets, 'Uploading payload to unpack')
  dispatch :upload_file_with_description do
    scope_param
    param 'String[1]', :source
    param 'String[1]', :destination
    param 'Boltlib::TargetSpec', :targets
    param 'String', :description
    optional_param 'Hash[String[1], Any]', :options
    return_type 'ResultSet'
  end

  def upload_file(scope, source, destination, targets, options = {})
    upload_file_with_description(scope, source, destination, targets, nil, options)
  end

  def upload_file_with_description(scope, source, destination, targets, description = nil, options = {})
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, action: 'upload_file')
    end

    options = options.select { |opt| opt.start_with?('_') }.transform_keys { |k| k.sub(/^_/, '').to_sym }
    options[:description] = description if description

    executor = Puppet.lookup(:bolt_executor)
    inventory = Puppet.lookup(:bolt_inventory)

    # Send Analytics Report
    executor.report_function_call(self.class.name)

    # Find the file path if it exists, otherwise return nil
    found = Bolt::Util.find_file_from_scope(source, scope)
    unless found && Puppet::FileSystem.exist?(found)
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::NO_SUCH_FILE_OR_DIRECTORY, file: source
      )
    end
    executor.report_file_source(self.class.name, source)
    # Ensure that that given targets are all Target instances
    targets = inventory.get_targets(targets)
    if targets.empty?
      call_function('debug', "Simulating file upload of '#{found}' - no targets given - no action taken")
      Bolt::ResultSet.new([])
    else
      file_line = Puppet::Pops::PuppetStack.top_of_stack
      r = if executor.in_parallel?
            executor.run_in_thread do
              executor.upload_file(targets, found, destination, options, file_line)
            end
          else
            executor.upload_file(targets, found, destination, options, file_line)
          end
      if !r.ok && !options[:catch_errors]
        raise Bolt::RunFailure.new(r, 'upload_file', source)
      end
      r
    end
  end
end
