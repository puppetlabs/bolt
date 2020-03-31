# frozen_string_literal: true

require 'tempfile'
require 'bolt/pal/issues'

# Write contents to a file on the given set of targets.
#
# > **Note:** Not available in apply block
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
    required_param 'String', :content
    required_param 'String[1]', :destination
    required_param 'Boltlib::TargetSpec', :targets
    optional_param 'Hash[String[1], Any]', :options
    return_type 'ResultSet'
  end

  def write_file(content, destination, target_spec, options = {})
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
                              action: 'write_file')
    end

    executor = Puppet.lookup(:bolt_executor)
    executor.report_function_call(self.class.name)

    inventory = Puppet.lookup(:bolt_inventory)
    targets = inventory.get_targets(target_spec)

    executor.log_action("write file #{destination}", targets) do
      executor.without_default_logging do
        Tempfile.create do |tmp|
          call_function('file::write', tmp.path, content)
          call_function('upload_file', tmp.path, destination, targets, options)
        end
      end
    end
  end
end
