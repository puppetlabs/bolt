# frozen_string_literal: true

# check if a file exists
Puppet::Functions.create_function(:'file::exists', Puppet::Functions::InternalFunction) do
  # @param filename Absolute path or Puppet file path.
  # @example Check a file on disk
  #   file::exists('/tmp/i_dumped_this_here')
  # @example check a file from the modulepath
  #   file::exists('example/files/VERSION')
  dispatch :exists do
    scope_param
    required_param 'String', :filename
    return_type 'Boolean'
  end

  def exists(scope, filename)
    found = Puppet::Parser::Files.find_file(filename, scope.compiler.environment)
    found && Puppet::FileSystem.exist?(found)
  end
end
