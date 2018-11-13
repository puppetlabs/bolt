# frozen_string_literal: true

module BoltSpec
  module Plans
    class UploadStub < ActionStub
      def matches(targets, _source, destination, options)
        if @invocation[:targets] && Set.new(@invocation[:targets]) != Set.new(targets.map(&:name))
          return false
        end

        if @invocation[:destination] && destination != @invocation[:destination]
          return false
        end

        if @invocation[:options] && options != @invocation[:options]
          return false
        end

        true
      end

      def call(targets, source, destination, options)
        @calls += 1
        if @return_block
          result_set = @return_block.call(targets: targets, source: source, destination: destination, params: options)
          unless result_set.is_a?(Bolt::ResultSet)
            raise "Return block for #{source} did not return a Bolt::ResultSet"
          end
          result_set
        else
          results = targets.map do |target|
            val = @data[target.name] || @data[:default]
            Bolt::Result.new(target, value: val)
          end
          Bolt::ResultSet.new(results)
        end
      end

      def parameters
        @invocation[:options]
      end

      # Public methods

      def with_destination(destination)
        @invocation[:destination] = destination
        self
      end

      def with_params(params)
        @invocation[:options] = params
        self
      end
    end
  end
end
