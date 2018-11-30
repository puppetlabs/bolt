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
          results = @return_block.call(targets: targets, source: source, destination: destination, params: options)
          check_resultset(results, source)
        else
          results = targets.map do |target|
            if @data[:default].is_a?(Bolt::Error)
              default_for(target)
            else
              Bolt::Result.for_upload(target, source, destination)
            end
          end
          Bolt::ResultSet.new(results)
        end
      end

      def parameters
        @invocation[:options]
      end

      def result_for(_target, _data)
        raise 'Upload result cannot be changed'
      end

      # Public methods

      def always_return(_data)
        raise 'Upload result cannot be changed'
      end

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
