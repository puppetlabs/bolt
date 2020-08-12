# frozen_string_literal: true

# Repeat the block until it returns a truthy value. Returns the value.
Puppet::Functions.create_function(:'ctrl::do_until') do
  # @param options A hash of additional options.
  # @option options [Numeric] limit The number of times to repeat the block.
  # @option options [Numeric] interval The number of seconds to wait before repeating the block.
  # @example Run a task until it succeeds
  #   ctrl::do_until() || {
  #     run_task('test', $target, '_catch_errors' => true).ok()
  #   }
  # @example Run a task until it succeeds or fails 10 times
  #   ctrl::do_until('limit' => 10) || {
  #     run_task('test', $target, '_catch_errors' => true).ok()
  #   }
  # @example Run a task and wait 10 seconds before running it again
  #   ctrl::do_until('interval' => 10) || {
  #     run_task('test', $target, '_catch_errors' => true).ok()
  #   }
  dispatch :do_until do
    optional_param 'Hash[String[1], Any]', :options
    block_param
  end

  def do_until(options = {})
    # Send Analytics Report
    Puppet.lookup(:bolt_executor) {}&.report_function_call(self.class.name)

    limit = options['limit'] || 0
    interval = options['interval']

    i = 0
    until (x = yield)
      i += 1
      break if limit != 0 && i >= limit
      Kernel.sleep(interval) if interval
    end
    x
  end
end
