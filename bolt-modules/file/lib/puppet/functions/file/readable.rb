# frozen_string_literal: true

# check if a file is readable
Puppet::Functions.create_function(:'file::readable', Puppet::Functions::InternalFunction) do
  # @param filename Absolute path or Puppet file path.
  # @example Check a file on disk
  #   file::readable('/tmp/i_dumped_this_here')
  # @example check a file from the modulepath
  #   file::readable('example/files/VERSION')
  dispatch :readable do
    scope_param
    required_param 'String', :filename
    return_type 'Boolean'
  end

  def readable(scope, filename)
    Puppet.lookup(:bolt_executor) {}&.report_function_call(self.class.name)
    found = Puppet::Parser::Files.find_file(filename, scope.compiler.environment)
    found && File.readable?(found)
  end
end
