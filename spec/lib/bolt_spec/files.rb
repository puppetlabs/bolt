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
      Tempfile.open(params, Dir.pwd) do |file|
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

    # Stubs a path so it looks like a directory.
    #
    # @param path [String] The path to the directory.
    #
    def stub_directory(path)
      double('stat', readable?: true, file?: false, directory?: true).tap do |double|
        allow(Bolt::Util).to receive(:file_stat).with(path).and_return(double)
      end
    end

    # Stubs a path so it looks like a file.
    #
    # @param path [String] The path to the file.
    #
    def stub_file(path)
      double('stat', readable?: true, file?: true, directory?: false).tap do |double|
        allow(Bolt::Util).to receive(:file_stat).with(path).and_return(double)
      end
    end

    # Stubs a path so it looks like a nonexistent file.
    #
    # @param path [String] The path to the nonexistent file.
    #
    def stub_nonexistent_file(path)
      allow(Bolt::Util).to receive(:file_stat).with(path).and_raise(
        Errno::ENOENT, "No such file or directory @ rb_file_s_stat - #{path}"
      )
      nil
    end

    # Stubs a path so it looks like an unreadable file.
    #
    # @param path [String] The path to the unreadable file.
    #
    def stub_unreadable_file(path)
      double('stat', readable?: false, file?: true).tap do |double|
        allow(Bolt::Util).to receive(:file_stat).with(path).and_return(double)
      end
    end
  end
end
