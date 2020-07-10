# frozen_string_literal: true

require 'pathname'
require 'bolt/error'

# Downloads the given file or directory from the given set of targets and saves it to a directory
# matching the target's name under the given destination directory. Returns the result from each
# download. This does nothing if the list of targets is empty.
#
# > **Note:** Existing content in the destination directory is deleted before downloading from
# > the targets.
#
# > **Note:** Not available in apply block
Puppet::Functions.create_function(:download_file, Puppet::Functions::InternalFunction) do
  # Download a file or directory.
  # @param source The absolute path to the file or directory on the target(s).
  # @param destination The relative path to the destination directory on the local system. Expands
  #                    relative to `<project>/downloads/`.
  # @param targets A pattern identifying zero or more targets. See {get_targets} for accepted patterns.
  # @param options A hash of additional options.
  # @option options [Boolean] _catch_errors Whether to catch raised errors.
  # @option options [String] _run_as User to run as using privilege escalation.
  # @return A list of results, one entry per target, with the path to the downloaded file under the
  #         `path` key.
  # @example Download a file from multiple Linux targets to a destination directory
  #   download_file('/etc/ssh/ssh_config', '~/Downloads', $targets)
  # @example Download a directory from multiple Linux targets to a project downloads directory
  #   download_file('/etc/ssh', 'ssh', $targets)
  # @example Download a file from multiple Linux targets and compare its contents to a local file
  #   $results = download_file($source, $destination, $targets)
  #
  #   $local_content = file::read($source)
  #
  #   $mismatched_files = $results.filter |$result| {
  #     $remote_content = file::read($result['path'])
  #     $remote_content == $local_content
  #   }
  dispatch :download_file do
    param 'String[1]', :source
    param 'String[1]', :destination
    param 'Boltlib::TargetSpec', :targets
    optional_param 'Hash[String[1], Any]', :options
    return_type 'ResultSet'
  end

  # Download a file or directory, logging the provided description.
  # @param source The absolute path to the file or directory on the target(s).
  # @param destination The relative path to the destination directory on the local system. Expands
  #                    relative to `<project>/downloads/`.
  # @param targets A pattern identifying zero or more targets. See {get_targets} for accepted patterns.
  # @param description A description to be output when calling this function.
  # @param options A hash of additional options.
  # @option options [Boolean] _catch_errors Whether to catch raised errors.
  # @option options [String] _run_as User to run as using privilege escalation.
  # @return A list of results, one entry per target, with the path to the downloaded file under the
  #         `path` key.
  # @example Download a file from multiple Linux targets to a destination directory
  #   download_file('/etc/ssh/ssh_config', '~/Downloads', $targets, 'Downloading remote SSH config')
  dispatch :download_file_with_description do
    param 'String[1]', :source
    param 'String[1]', :destination
    param 'Boltlib::TargetSpec', :targets
    param 'String', :description
    optional_param 'Hash[String[1], Any]', :options
    return_type 'ResultSet'
  end

  def download_file(source, destination, targets, options = {})
    download_file_with_description(source, destination, targets, nil, options)
  end

  def download_file_with_description(source, destination, targets, description = nil, options = {})
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, action: 'download_file')
    end

    options = options.select { |opt| opt.start_with?('_') }.transform_keys { |k| k.sub(/^_/, '').to_sym }
    options[:description] = description if description

    executor = Puppet.lookup(:bolt_executor)
    inventory = Puppet.lookup(:bolt_inventory)

    if (destination = destination.strip).empty?
      raise Bolt::ValidationError, "Destination cannot be an empty string"
    end

    if (destination = Pathname.new(destination)).absolute?
      raise Bolt::ValidationError, "Destination must be a relative path, received absolute path #{destination}"
    end

    # Prevent path traversal so downloads can't be saved outside of the project downloads directory
    if (destination.each_filename.to_a & %w[. ..]).any?
      raise Bolt::ValidationError, "Destination must not include path traversal, received #{destination}"
    end

    # Paths expand relative to the default downloads directory for the project
    # e.g. ~/.puppetlabs/bolt/downloads/
    destination = Puppet.lookup(:bolt_project_data).downloads + destination

    # If the destination directory already exists, delete any existing contents
    if Dir.exist?(destination)
      FileUtils.rm_r(Dir.glob(destination + '*'), secure: true)
    end

    # Send Analytics Report
    executor.report_function_call(self.class.name)

    # Ensure that that given targets are all Target instances
    targets = inventory.get_targets(targets)
    if targets.empty?
      call_function('debug', "Simulating file download of '#{source}' - no targets given - no action taken")
      r = Bolt::ResultSet.new([])
    else
      r = executor.download_file(targets, source, destination, options)
    end

    if !r.ok && !options[:catch_errors]
      raise Bolt::RunFailure.new(r, 'download_file', source)
    end
    r
  end
end
