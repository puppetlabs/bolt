# frozen_string_literal: true

module SleepSignal
  def self.sleep_with_signal_handler(period)
    # When running with a jruby interpreter sleep will handle an iterrupt and allow the plan to keep
    # running. In order to have consistent behavior between plans in bolt and PE and to ensure plans
    # are able to be reliably stopped we add a signal handler to raise an exception on interrupt.
    handler = Signal.trap(:INT) { raise Puppet::Error, "interrupt signal received during sleep" }
    Kernel.sleep(period)
  ensure
    Signal.trap :INT, handler if handler
  end
end
