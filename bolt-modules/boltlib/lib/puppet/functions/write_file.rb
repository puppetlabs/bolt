# frozen_string_literal: true

require 'tempfile'

# Write contents to a file on the given set of targets.
#
# > **Note:** Not available in apply block
#
# > **Note:** Files are granted 0600 permissions. If a file contains sensitive content
# > that requires a change of permissions, make sure to update the permissions outside
# > the use of this function.
Puppet::Functions.create_function(:write_file) do
  # @param targets A pattern identifying zero or more targets. See {get_targets} for accepted patterns.
  # @param content File content to write.
  # @param destination An absolute path on the target(s).
  # @option options [Boolean] _catch_errors Whether to catch raised errors.
  # @option options [String] _run_as User to run as using privilege escalation.
  # @return A list of results, one entry per target.
  # @example Write a file to a target
  #   $content = 'Hello, world!'
  #   write_file($targets, $content, '/Users/me/hello.txt')
  dispatch :write_file do
    required_param 'Boltlib::TargetSpec', :targets
    required_param 'String', :content
    required_param 'String[1]', :destination
    optional_param 'Hash[String[1], Any]', :options
    return_type 'ResultSet'
  end

  def write_file(content, destination, targets, options = {})
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
                              action: 'write_file')
    end

    executor = Puppet.lookup(:bolt_executor)
    executor.report_function_call(self.class.name)

    executor.log_action("write file to #{destination}", targets) do
      executor.without_default_logging do
        Tempfile.create do |tmp|
          call_function('file::write', tmp.path, content)
          call_function('upload_file', tmp.path, destination, targets, options)
        end
      end
    end
  end
end
