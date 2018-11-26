# frozen_string_literal: true

require 'bolt/task'

module Bolt
  class Task
    class Remote < Task
      def self.from_task(task)
        new(task.name, task.file, task.files, task.metadata)
      end

      def implementations
        metadata['implementations']&.select { |i| i['remote'] || metadata['remote'] }
      end

      def select_implementation(target, *args)
        unless implementations || metadata['remote']
          raise NoImplementationError.new(target, self)
        end

        super(target, *args)
      end
    end
  end
end
