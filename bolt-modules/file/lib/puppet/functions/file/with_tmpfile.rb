# frozen_string_literal: true

require 'tempfile'

# Create a temporary file and execute the block with the filename created as an
# argument. The file is deleted after the block execution. This will only
# operate on the machine you run Bolt on.
Puppet::Functions.create_function(:'file::with_tmpfile') do
  # @param basename Determines the name of the temporary file (see ruby's Tempfile.new)
  # @param tmpdir Directory to place the temporary file in (ruby's Dir.tmpdir is default value)
  # @param block The block to execute with a temporary filename
  # @example Run a command with a temporary file
  #   # NOTE: This will work on the Bolt controller node only!
  #   $res = file::with_tmpfile('foo') |$filename| {
  #     run_command("do_something_with '${filename}'", 'localhost')
  #     upload_file($filename, $targets)
  #   }
  dispatch :with_tmpfile do
    param 'String', :basename
    optional_param 'Optional[String[1]]', :tmpdir
    block_param 'Callable[1, 1]', :block
    return_type 'Any'
  end

  def with_tmpfile(basename = '', tmpdir = nil)
    # Send Analytics Report
    Puppet.lookup(:bolt_executor) {}&.report_function_call(self.class.name)

    f = Tempfile.new(basename, tmpdir)
    f.close
    begin
      result = yield f.path
    ensure
      f.unlink
    end

    result
  end
end
