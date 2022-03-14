# frozen_string_literal: true

require 'bolt_server/file_cache'

module BoltSpec
  module FileCache
    class MockFileCache
      def initialize(moduledir)
        @moduledir = moduledir
      end

      def setup
        self
      end

      def update_file(file_data)
        parts = file_data['filename'].split('/')
        modulename = 'sample'
        if parts.size == 1
          File.join(@moduledir, modulename, 'tasks', parts[0])
        else
          File.join(@moduledir, *parts)
        end
      end

      def get_cached_project_file(_versioned_project, _file_name); end

      def cache_project_file(_versioned_project, _file_name, data)
        data
      end
    end

    # TODO: support more than just the sample module
    def mock_file_cache(moduledir)
      mock_cache = MockFileCache.new(moduledir)
      allow(::BoltServer::FileCache).to receive(:new).and_return(mock_cache)
    end
  end
end
