# frozen_string_literal: true

# Write a string to a file on localhost using ruby's `File.write`. This will
# only write files to the machine you run Bolt on. Use `write_file()` to write
# to remote targets.
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
    executor = Puppet.lookup(:bolt_executor) {}

    # executor.noop is set when using 'plan run --noop' from the CLI
    if executor&.noop
      raise Bolt::Error.new('file::write is not supported in noop mode', 'bolt/noop-error')
    end

    # Send Analytics Report
    executor&.report_function_call(self.class.name)

    File.write(filename, content)
    nil
  end
end
