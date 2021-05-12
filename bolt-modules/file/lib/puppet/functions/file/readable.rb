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
    required_param 'String[1]', :filename
    return_type 'Boolean'
  end

  def readable(scope, filename)
    # Send Analytics Report
    executor = Puppet.lookup(:bolt_executor) {}
    executor&.report_function_call(self.class.name)

    future = executor&.future || {}
    fallback = future.fetch('file_paths', false)

    # Find the file path if it exists, otherwise return nil
    found = Bolt::Util.find_file_from_scope(filename, scope, fallback)
    found ? File.readable?(found) : false
  end
end
