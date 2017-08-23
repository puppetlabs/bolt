require 'tempfile'

module BoltSpec
  module Files
    def with_tempfile_containing(name, contents)
      Tempfile.open(name) do |file|
        file.write(contents)
        file.flush
        yield file
      end
    end
  end
end
