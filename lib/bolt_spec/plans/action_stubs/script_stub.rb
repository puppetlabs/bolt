# frozen_string_literal: true

module BoltSpec
  module Plans
    class ScriptStub < ActionStub
      def matches(targets, _script, arguments, options)
        if @invocation[:targets] && Set.new(@invocation[:targets]) != Set.new(targets.map(&:name))
          return false
        end

        if @invocation[:arguments] && arguments != @invocation[:arguments]
          return false
        end

        if @invocation[:options] && options != @invocation[:options]
          return false
        end

        true
      end

      def call(targets, script, arguments, options)
        @calls += 1
        if @return_block
          # Merge arguments and options into params to match puppet function signature.
          params = options.merge('arguments' => arguments)
          result_set = @return_block.call(targets: targets, script: script, params: params)
          unless result_set.is_a?(Bolt::ResultSet)
            raise "Return block for #{script} did not return a Bolt::ResultSet"
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
        @invocation[:arguments] + @invocation[:options]
      end

      # Public methods

      def with_params(params)
        @invocation[:arguments] = params['arguments']
        @invocation[:options] = params.select { |k, _v| k.start_with?('_') }
        self
      end
    end
  end
end
