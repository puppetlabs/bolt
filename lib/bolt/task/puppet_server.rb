# frozen_string_literal: true

module Bolt
  class Task
    class PuppetServer < Bolt::Task
      def remote_instance
        self.class.new(@name, @metadata, @files, @file_cache, true)
      end

      def initialize(name, metadata, files, file_cache, remote = false)
        super(name, metadata, files, remote)
        @file_cache = file_cache
        update_file_data
      end

      # puppetserver file entries have 'filename' rather then 'name'
      def update_file_data
        @files.each { |f| f['name'] = f['filename'] }
      end

      def file_path(file_name)
        file = file_map[file_name]
        file['path'] ||= @file_cache.update_file(file)
      end
    end
  end
end
