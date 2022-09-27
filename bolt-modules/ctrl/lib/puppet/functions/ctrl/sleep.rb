# frozen_string_literal: true

require_relative '../../../shared/sleep_signal'

# Sleeps for specified number of seconds.
Puppet::Functions.create_function(:'ctrl::sleep') do
  # @param period Time to sleep (in seconds)
  # @example Sleep for 5 seconds
  #   ctrl::sleep(5)
  dispatch :sleeper do
    required_param 'Numeric', :period
    return_type 'Undef'
  end

  def sleeper(period)
    # Send Analytics Report
    Puppet.lookup(:bolt_executor) {}&.report_function_call(self.class.name)
    SleepSignal.sleep_with_signal_handler(period)
    nil
  end
end
