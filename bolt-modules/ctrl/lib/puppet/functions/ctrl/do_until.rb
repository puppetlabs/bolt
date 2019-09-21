# frozen_string_literal: true

# Repeat the block until it returns a truthy value. Returns the value.
Puppet::Functions.create_function(:'ctrl::do_until') do
  # @example Run a task until it succeeds
  #   ctrl::do_until() || {
  #     run_task('test', $target, _catch_errors => true).ok?
  #   }
  dispatch :do_until do
    block_param
  end

  def do_until
    Puppet.lookup(:bolt_executor) {}&.report_function_call(self.class.name)
    until (x = yield); end
    x
  end
end
