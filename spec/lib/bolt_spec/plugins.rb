# frozen_string_literal: true

module BoltSpec
  module Plugins
    # Implements a resolve_reference plugin that returns the given "value"
    class Constant
      def name
        'constant'
      end

      def hooks
        [:resolve_reference]
      end

      def resolve_reference(opts)
        opts['value']
      end
    end

    # Implements a resolve_reference plugin that raises an error when called
    class Error
      def name
        'error'
      end

      def hooks
        [:resolve_reference]
      end

      def resolve_reference(_opts)
        raise "The Error plugin was called"
      end
    end

    class TestLookup
      def initialize(data)
        @data = data
      end

      def name
        'test_lookup'
      end

      def hooks
        [:resolve_reference]
      end

      def resolve_reference(opts)
        key = opts['key']
        if @data.key?(key)
          @data[key]
        else
          raise "No lookup value set for key '#{key}'"
        end
      end
    end
  end
end
