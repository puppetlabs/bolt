# frozen_string_literal: true

# Read a file on localhost and return its contents using ruby's `File.read`. This will
# only read files on the machine you run Bolt on.
Puppet::Functions.create_function(:'file::read', Puppet::Functions::InternalFunction) do
  # @param filename Absolute path or Puppet file path.
  # @return The file's contents.
  # @example Read a file from disk
  #   file::read('/tmp/i_dumped_this_here')
  # @example Read a file from the modulepath
  #   file::read('example/VERSION')
  dispatch :read do
    scope_param
    required_param 'String', :filename
    return_type 'String'
  end

  def read(scope, filename)
    # Send Analytics Report
    Puppet.lookup(:bolt_executor) {}&.report_function_call(self.class.name)

    found = Puppet::Parser::Files.find_file(filename, scope.compiler.environment)
    unless found && Puppet::FileSystem.exist?(found)
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::NO_SUCH_FILE_OR_DIRECTORY, file: filename
      )
    end

    File.read(found)
  end
end
