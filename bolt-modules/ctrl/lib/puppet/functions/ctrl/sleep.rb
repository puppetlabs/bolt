# frozen_string_literal: true

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
    sleep(period)
    nil
  end
end
