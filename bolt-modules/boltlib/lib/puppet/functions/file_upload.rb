# frozen_string_literal: true

require 'bolt/error'

# Uploads the given file or directory to the given set of targets and returns the result from each upload.
# This function does nothing if the list of targets is empty.
Puppet::Functions.create_function(:file_upload, Puppet::Functions::InternalFunction) do
  # Upload a file.
  # @param source A source path, either an absolute path or a modulename/filename selector for a file in
  #               <moduleroot>/files.
  # @param destination An absolute path on the target(s).
  # @param targets A pattern identifying zero or more targets. See {get_targets} for accepted patterns.
  # @param options Additional options: '_catch_errors', '_run_as'.
  # @return A list of results, one entry per target.
  # @example Upload a local file to Linux targets and change owner to 'root'
  #   file_upload('/var/tmp/payload.tgz', '/tmp/payload.tgz', $targets, '_run_as' => 'root')
  # @example Upload a module file to a Windows target
  #   file_upload('postgres/default.conf', 'C:/ProgramData/postgres/default.conf', $target)
  dispatch :file_upload do
    scope_param
    param 'String[1]', :source
    param 'String[1]', :destination
    param 'Boltlib::TargetSpec', :targets
    optional_param 'Hash[String[1], Any]', :options
    return_type 'ResultSet'
  end

  # Upload a file, logging the provided description.
  # @param source A source path, either an absolute path or a modulename/filename selector for a file in
  #               <moduleroot>/files.
  # @param destination An absolute path on the target(s).
  # @param targets A pattern identifying zero or more targets. See {get_targets} for accepted patterns.
  # @param description A description to be output when calling this function.
  # @param options Additional options: '_catch_errors', '_run_as'.
  # @return A list of results, one entry per target.
  # @example Upload a file
  #   file_upload('/var/tmp/payload.tgz', '/tmp/payload.tgz', $targets, 'Uploading payload to unpack')
  dispatch :file_upload_with_description do
    scope_param
    param 'String[1]', :source
    param 'String[1]', :destination
    param 'Boltlib::TargetSpec', :targets
    param 'String', :description
    optional_param 'Hash[String[1], Any]', :options
    return_type 'ResultSet'
  end

  def file_upload(scope, source, destination, targets, options = nil)
    file_upload_with_description(scope, source, destination, targets, nil, options)
  end

  def file_upload_with_description(scope, source, destination, targets, description = nil, options = nil)
    options ||= {}
    options = options.merge('_description' => description) if description

    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, operation: 'file_upload'
      )
    end

    executor = Puppet.lookup(:bolt_executor) { nil }
    inventory = Puppet.lookup(:bolt_inventory) { nil }
    unless executor && inventory && Puppet.features.bolt?
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_MISSING_BOLT, action: _('do file uploads')
      )
    end

    found = Puppet::Parser::Files.find_file(source, scope.compiler.environment)
    unless found && Puppet::FileSystem.exist?(found)
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::NO_SUCH_FILE_OR_DIRECTORY, file: source
      )
    end

    # Ensure that that given targets are all Target instances
    targets = inventory.get_targets(targets)
    if targets.empty?
      call_function('debug', "Simulating file upload of '#{found}' - no targets given - no action taken")
      r = Bolt::ResultSet.new([])
    else
      r = executor.file_upload(targets, found, destination, options)
    end

    if !r.ok && !options['_catch_errors']
      raise Bolt::RunFailure.new(r, 'upload_file', source)
    end
    r
  end
end
