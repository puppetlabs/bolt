# frozen_string_literal: true

require 'bolt/task'

module Bolt
  class Task
    class PuppetServer < Bolt::Task
      def initialize(task_data, file_cache)
        @file_cache = file_cache
        task_data = update_file_data(task_data)
        super(task_data)
      end

      # puppetserver file entries have 'filename' rather then 'name'
      def update_file_data(task_data)
        task_data['files'].each { |f| f['name'] = f['filename'] }
        task_data
      end

      # Compute local path and download files from puppetserver as needed
      def file_path(file_name)
        file = file_map[file_name]
        file['path'] ||= @file_cache.update_file(file)
      end
    end
  end
end
