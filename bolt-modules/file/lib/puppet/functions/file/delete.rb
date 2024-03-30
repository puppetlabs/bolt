# frozen_string_literal: true

# Delete a file on localhost using ruby's `File.delete`. This will only delete
# files on the machine you run Bolt on.
Puppet::Functions.create_function(:'file::delete') do
  # @param filename Absolute path.
  # @example Delete a file from disk
  #   file::delete('C:/Users/me/report')
  dispatch :delete do
    required_param 'String[1]', :filename
    return_type 'Undef'
  end

  def delete(filename)
    # Send Analytics Report
    Puppet.lookup(:bolt_executor) {}&.report_function_call(self.class.name)

    File.delete(filename)
    nil
  end
end
