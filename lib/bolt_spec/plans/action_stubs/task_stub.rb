# frozen_string_literal: true

module BoltSpec
  module Plans
    class TaskStub < ActionStub
      def matches(targets, _task, arguments, options)
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

      def call(targets, task, arguments, options)
        @calls += 1
        if @return_block
          # Merge arguments and options into params to match puppet function signature.
          check_resultset(@return_block.call(targets: targets, task: task, params: arguments.merge(options)), task)
        else
          Bolt::ResultSet.new(targets.map { |target| @data[target.name] || default_for(target) })
        end
      end

      def parameters
        @invocation[:params]
      end

      # Allow any data.
      def result_for(target, data)
        Bolt::Result.new(target, value: Bolt::Util.walk_keys(data, &:to_s))
      end

      # Public methods

      # Restricts the stub to only match invocations with certain parameters.
      # All parameters must match exactly.
      def with_params(params)
        @invocation[:params] = params
        @invocation[:arguments] = params.reject { |k, _v| k.start_with?('_') }
        @invocation[:options] = params.select { |k, _v| k.start_with?('_') }
        self
      end
    end
  end
end
