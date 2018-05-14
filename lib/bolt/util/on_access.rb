# frozen_string_literal: true

module Bolt
  module Util
    class OnAccess
      def initialize(&block)
        @constructor = block
        @obj = nil
      end

      # If a method is called and we haven't constructed the object,
      # construct it. Then pass the call to the object.
      # rubocop:disable Style/MethodMissingSuper
      # rubocop:disable Style/MissingRespondToMissing
      def method_missing(method, *args, &block)
        if @obj.nil?
          @obj = @constructor.call
        end

        @obj.send(method, *args, &block)
      end
      # rubocop:enable Style/MethodMissingSuper
      # rubocop:enable Style/MissingRespondToMissing
    end
  end
end
