# frozen_string_literal: true

# Check if a local file exists using Puppet's
# `Puppet::Parser::Files.find_file()` function. This will only check files that
# are on the machine Bolt is run on.
Puppet::Functions.create_function(:'file::exists', Puppet::Functions::InternalFunction) do
  # @param filename Absolute path or Puppet file path.
  # @return Whether the file exists.
  # @example Check a file on disk
  #   file::exists('/tmp/i_dumped_this_here')
  # @example check a file from the modulepath
  #   file::exists('example/VERSION')
  dispatch :exists do
    scope_param
    required_param 'String[1]', :filename
    return_type 'Boolean'
  end

  def exists(scope, filename)
    # Send Analytics Report
    executor = Puppet.lookup(:bolt_executor) {}
    executor&.report_function_call(self.class.name)

    future = executor&.future || Puppet.lookup(:future) || {}
    fallback = future.fetch('file_paths', false)

    # Find the file path if it exists, otherwise return nil
    found = Bolt::Util.find_file_from_scope(filename, scope, fallback)
    found ? Puppet::FileSystem.exist?(found) : false
  end
end
