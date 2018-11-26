# frozen_string_literal: true

require 'bolt/transport/base'


module Bolt
  module Transport
    class Remote < Base
      def self.options
        # TODO: We should accept arbitrary options here
        %w[host port user password connnect-timeout device-type run-on]
      end

      def self.validate(options)
        # This will fail when validating global config
        #unless options['device-type']
        #  raise Bolt::ValidationError, 'Must specify device-type for devices'
        #end
      end

      # TODO: this should have access to inventory so target doesn't have to
      def initialize(executor)
        super()

        @executor = executor
      end

      def get_proxy(target)
        # TODO: This needs to have access to the inventory
        inventory = target.instance_variable_get(:@inventory)
        raise "Target was creates without inventory? Not get_targets?" unless inventory
        inventory.get_targets(target.options['run-on'] || 'localhost').first
      end

      # Cannot batch because arugments differ
      def run_task(target, task, arguments, options = {})
        proxy_target = get_proxy(target)
        transport = @executor.transport(proxy_target.protocol)
        arguments = arguments.merge('_target' => target.to_h.reject {|_, v| v.nil?})

        # TODO: add support for device-type and feature checking here.
        # * tasks/task_implementations must have the same device-type as the target
        # * Does one implementation need to support multiple device types?
        # * Do we need multiple implementations for the same device based on proxy features?
        # TODO doesn't support transports with only batch exec(orchestrator). update orch
        result = transport.run_task(proxy_target, task, arguments, options)

        Bolt::Result.new(target, value: result.value)
      end
    end
  end
end
