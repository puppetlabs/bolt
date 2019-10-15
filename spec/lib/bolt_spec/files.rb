# frozen_string_literal: true

require 'tempfile'

module BoltSpec
  module Files
    def with_tempfile_containing(name, contents, extension = nil)
      params = if extension
                 [name, extension]
               else
                 name
               end
      Tempfile.open(params) do |file|
        file.binmode # Stop Ruby implicitly doing CRLF translations and breaking tests
        file.write(contents)
        file.flush
        yield file
      end
    end

    def fixtures_path(*path)
      if path
        File.absolute_path(File.join(__dir__, '..', '..', 'fixtures', path))
      else
        File.absolute_path(File.join(__dir__, '..', '..', 'fixtures'))
      end
    end
    module_function :fixtures_path
  end
end
