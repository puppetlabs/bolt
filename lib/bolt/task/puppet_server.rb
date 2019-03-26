# frozen_string_literal: true

module Bolt
  class Task
    class PuppetServer < Bolt::Task
      def remote_instance
        self.class.new(to_h.each_with_object({}) { |(k, v), h| h[k.to_s] = v },
                       @file_cache,
                       remote: true)
      end

      def initialize(task, file_cache, **opts)
        super(task, **opts)
        @file_cache = file_cache
        update_file_data(task)
      end

      # puppetserver file entries have 'filename' rather then 'name'
      def update_file_data(task_data)
        task_data['files'].each { |f| f['name'] = f['filename'] }
        task_data
      end

      def file_path(file_name)
        file = file_map[file_name]
        file['path'] ||= @file_cache.update_file(file)
      end
    end
  end
end
