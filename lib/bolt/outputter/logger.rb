# frozen_string_literal: true

require 'bolt/pal'

module Bolt
  class Outputter
    class Logger < Bolt::Outputter
      def initialize(verbose, trace)
        super(false, verbose, trace, false)
        @logger = Bolt::Logger.logger(self)
      end

      def handle_event(event)
        case event[:type]
        when :step_start
          log_step_start(**event)
        when :step_finish
          log_step_finish(**event)
        when :plan_start
          log_plan_start(event)
        when :plan_finish
          log_plan_finish(event)
        when :container_start
          log_container_start(event)
        when :container_finish
          log_container_finish(event)
        when :log, :message, :verbose
          log_message(**event)
        end
      end

      def log_step_start(description:, targets:, **_kwargs)
        target_str = if targets.length > 5
                       "#{targets.count} targets"
                     else
                       targets.map(&:safe_name).join(', ')
                     end
        @logger.info("Starting: #{description} on #{target_str}")
      end

      def log_step_finish(description:, result:, duration:, **_kwargs)
        failures = result.error_set.length
        plural = failures == 1 ? '' : 's'
        @logger.info("Finished: #{description} with #{failures} failure#{plural} in #{duration.round(2)} sec")
      end

      def log_plan_start(event)
        plan = event[:plan]
        @logger.info("Starting: plan #{plan}")
      end

      def log_plan_finish(event)
        plan = event[:plan]
        duration = event[:duration]
        @logger.info("Finished: plan #{plan} in #{duration.round(2)} sec")
      end

      def log_container_start(event)
        @logger.info("Starting: run container '#{event[:image]}'")
      end

      def log_container_finish(event)
        result = event[:result]
        if result.success?
          @logger.info("Finished: run container '#{result.object}' succeeded.")
        else
          @logger.info("Finished: run container '#{result.object}' failed.")
        end
      end

      def log_message(level:, message:, **_kwargs)
        @logger.send(level, message)
      end
    end
  end
end
