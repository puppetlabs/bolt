# frozen_string_literal: true

require 'bolt/task'

module Bolt
  class Task
    class Remote < Task
      def self.from_task(task)
        new(task.to_h.each_with_object({}) { |(k, v), h| h[k.to_s] = v }, task.file_cache)
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
