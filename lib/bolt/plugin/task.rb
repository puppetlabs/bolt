# frozen_string_literal: true

module Bolt
  class Plugin
    class Task
      def hooks
        %w[inventory_targets inventory_config]
      end

      def name
        'task'
      end

      # This creates it's own PAL so we don't have to pass a promise around
      #
      def initialize(config)
        @config = config
      end

      attr_reader :config

      def pal
        # Hiera config should not be used yet.
        @pal ||= Bolt::PAL.new(config.modulepath, config.hiera_config)
      end

      def executor
        # Analytics should be handled at a higher level so create a new executor.
        @executor ||= Bolt::Executor.new
      end

      def inventory
        @inventory ||= Bolt::Inventory.new({}, config)
      end

      def run_task(opts)
        result = pal.run_task(opts['task'],
                              'localhost',
                              opts['parameters'] || {},
                              executor,
                              inventory).first

        raise Bolt::Error.new(result.error_hash['msg'], result.error_hash['kind']) if result.error_hash
        result
      end

      def validate_options(opts)
        raise Bolt::ValidationError, "Task plugin requires that the 'task' is specified" unless opts['task']

        task = pal.task_signature(opts['task'])

        raise Bolt::ValidationError, "Could not find task #{opts['task']}" unless task

        errors = []
        unless task.runnable_with?(opts['parameters'] || {}) { |msg| errors << msg }
          # This relies on runnable with printing a partial message before the first real error
          raise Bolt::ValidationError, "Invalid parameters for #{errors.join("\n")}"
        end
      end
      alias validate_inventory_config validate_options

      def inventory_config(opts)
        result = run_task(opts)

        unless result.value.include?('config')
          raise Bolt::ValidationError, "Task result did not return 'config': #{result.value}"
        end

        result['config']
      end

      def inventory_targets(opts)
        raise Bolt::ValidationError, "Task plugin requires that the 'task' is specified" unless opts['task']

        result = run_task(opts)

        targets = result['targets']
        unless targets.is_a?(Array)
          raise Bolt::ValidationError, "Task result did not return a targets array: #{result.value}"
        end

        unless targets.all? { |t| t.is_a?(Hash) }
          msg = "All targets returned by an inventory targets task must be hashes, got: #{targets}"
          raise Bolt::ValidationError, msg
        end

        targets
      end
    end
  end
end
