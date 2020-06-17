# frozen_string_literal: true

# Check if a local file is readable using Puppet's
# `Puppet::Parser::Files.find_file()` function. This will only check files on the
# machine you run Bolt on.
Puppet::Functions.create_function(:'file::readable', Puppet::Functions::InternalFunction) do
  # @param filename Absolute path or Puppet file path.
  # @return Whether the file is readable.
  # @example Check a file on disk
  #   file::readable('/tmp/i_dumped_this_here')
  # @example check a file from the modulepath
  #   file::readable('example/VERSION')
  dispatch :readable do
    scope_param
    required_param 'String', :filename
    return_type 'Boolean'
  end

  def readable(scope, filename)
    Puppet.lookup(:bolt_executor) {}&.report_function_call(self.class.name)
    found = Puppet::Parser::Files.find_file(filename, scope.compiler.environment)
    found ? File.readable?(found) : false
  end
end
