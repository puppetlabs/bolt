# frozen_string_literal: true

module BoltSpec
  module Plans
    class CommandStub < ActionStub
      def matches(targets, _command, options)
        if @invocation[:targets] && Set.new(@invocation[:targets]) != Set.new(targets.map(&:name))
          return false
        end

        if @invocation[:options] && options != @invocation[:options]
          return false
        end

        true
      end

      def call(targets, command, options)
        @calls += 1
        if @return_block
          result_set = @return_block.call(targets: targets, command: command, params: options)
          unless result_set.is_a?(Bolt::ResultSet)
            raise "Return block for #{command} did not return a Bolt::ResultSet"
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

      def with_params(params)
        @invocation[:options] = params
        self
      end
    end
  end
end
