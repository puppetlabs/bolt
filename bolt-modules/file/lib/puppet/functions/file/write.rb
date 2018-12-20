# frozen_string_literal: true

# Write a string to a file.
Puppet::Functions.create_function(:'file::write') do
  # @param filename Absolute path.
  # @param content File content to write.
  # @example Write a file to disk
  #   file::write('C:/Users/me/report', $apply_result.first.report)
  dispatch :write do
    required_param 'String', :filename
    required_param 'String', :content
    return_type 'Undef'
  end

  def write(filename, content)
    File.write(filename, content)
    nil
  end
end
