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

      # TODO: currently this both converts filename -> name and fetches files to generate the path
      # In the future we should not generate paths until after the implementation is selected to avoid
      # unecessary fetching of files
      def update_file_data(task_data)
        if task_data['files']
          task_data['files'] = task_data['files'].map do |f|
            { 'name' => f['filename'],
              'path' => @file_cache.update_file(f) }
          end
        end

        task_data
      end
    end
  end
end
