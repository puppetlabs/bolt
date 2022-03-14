# frozen_string_literal: true

require 'bolt/result'
require 'bolt/util'

module BoltSpec
  module Plans
    class PublishStub < ActionStub
      def return
        raise "return is not implemented for out module functions"
      end

      def return_for_targets(_data)
        raise "return_for_targets is not implemented for out module functions"
      end

      def always_return(_data)
        raise "always_return is not implemented for out module functions"
      end

      def error_with(_data)
        raise "error_with is not implemented for out module functions"
      end

      def matches(message)
        if @invocation[:options] && message != @invocation[:options]
          return false
        end

        true
      end

      def call(_event)
        @calls += 1
      end

      def parameters
        @invocation[:options]
      end

      # Public methods

      def with_params(params)
        @invocation[:options] = params
        self
      end
    end
  end
end
