require 'bolt/logger'

# Uploads the given file or directory to the given set of targets and returns the result from each upload.
#
# * This function does nothing if the list of targets is empty.
# * It is possible to run on the target 'localhost'
# * A target is a String with a targets's hostname or a Target.
# * The returned value contains information about the result per target.
#
Puppet::Functions.create_function(:file_upload, Puppet::Functions::InternalFunction) do
  local_types do
    type 'TargetOrTargets = Variant[String[1], Target, Array[TargetOrTargets]]'
  end

  dispatch :file_upload do
    scope_param
    param 'String[1]', :source
    param 'String[1]', :destination
    repeated_param 'TargetOrTargets', :targets
    return_type 'ExecutionResult'
  end

  def log_summary(object, node_count, fail_count)
    format("Uploaded file %s on %d node%s with %d failure%s",
           object,
           node_count,
           node_count == 1 ? '' : 's',
           fail_count,
           fail_count == 1 ? '' : 's')
  end

  def file_upload(scope, source, destination, *targets)
    r = nil
    logger = Logger.instance
    logger.notice("Uploading file #{source} to #{destination}")
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, operation: 'file_upload'
      )
    end

    executor = Puppet.lookup(:bolt_executor) { nil }
    unless executor && Puppet.features.bolt?
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
    targets = targets.flatten.map { |t| t.is_a?(String) ? Bolt::Target.new(t) : t }
    if targets.empty?
      call_function('debug', "Simulating file upload of '#{found}' - no targets given - no action taken")
      r = Bolt::ExecutionResult::EMPTY_RESULT
    else
      # Awaits change in the executor, enabling it receive Target instances
      hosts = targets.map(&:host)

      r = Bolt::ExecutionResult.from_bolt(
        executor.file_upload(executor.from_uris(hosts), found, destination)
      )
    end
    logger.notice(log_summary(source, targets.size, r.error_nodes.count))
    r
  end
end
