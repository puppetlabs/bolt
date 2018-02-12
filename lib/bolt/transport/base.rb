require 'concurrent'
require 'logging'

module Bolt
  module Transport
    class Base
      attr_reader :logger

      def initialize(_config, executor = Concurrent.global_immediate_executor)
        @logger = Logging.logger[self]
        @executor = executor
      end

      def on(targets, callback)
        targets.map do |target|
          Concurrent::Future.execute(executor: @executor) do
            begin
              callback.call(type: :node_start, target: target) if callback
              result = yield target
              @logger.debug("Result on #{target.uri}: #{JSON.dump(result.value)}")
              callback.call(type: :node_result, result: result) if callback
              result
            rescue StandardError => ex
              Bolt::Result.from_exception(target, ex)
            end
          end
        end
      end

      def filter_options(target, options)
        if target.options[:run_as]
          options.reject { |k, _v| k == '_run_as' }
        else
          options
        end
      end

      def batch_task(targets, task, input_method, arguments, options = {})
        callback = Proc.new if block_given?
        on(targets, callback) do |target|
          @logger.debug { "Running task run '#{task}' on #{target.uri}" }
          target_options = filter_options(target, options)
          run_task(target, task, input_method, arguments, target_options)
        end
      end

      def batch_command(targets, command, options = {})
        callback = Proc.new if block_given?
        on(targets, callback) do |target|
          @logger.debug("Running command '#{command}' on #{target.uri}")
          run_command(target, command, filter_options(target, options))
        end
      end

      def run_command(*_args)
        raise NotImplementedError, "run_command() must be implemented by the transport class"
      end

      def run_script(*_args)
        raise NotImplementedError, "run_script() must be implemented by the transport class"
      end

      def run_task(*_args)
        raise NotImplementedError, "run_task() must be implemented by the transport class"
      end

      def upload(*_args)
        raise NotImplementedError, "upload() must be implemented by the transport class"
      end
    end
  end
end
