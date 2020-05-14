# frozen_string_literal: true

# Join file paths using ruby's `File.join()` function.
Puppet::Functions.create_function(:'file::join') do
  # @param paths The paths to join.
  # @return The joined file path.
  # @example Join file paths
  #   file::join('./path', 'to/files')
  dispatch :join do
    required_repeated_param 'String', :paths
    return_type 'String'
  end

  def join(*paths)
    Puppet.lookup(:bolt_executor) {}&.report_function_call(self.class.name)
    File.join(paths)
  end
end
