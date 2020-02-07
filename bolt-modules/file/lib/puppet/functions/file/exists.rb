# frozen_string_literal: true

# Check if a file exists.
Puppet::Functions.create_function(:'file::exists', Puppet::Functions::InternalFunction) do
  # @param filename Absolute path or Puppet file path.
  # @return Whether the file exists.
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
    Puppet.lookup(:bolt_executor) {}&.report_function_call(self.class.name)
    found = Puppet::Parser::Files.find_file(filename, scope.compiler.environment)
    found ? Puppet::FileSystem.exist?(found) : false
  end
end
