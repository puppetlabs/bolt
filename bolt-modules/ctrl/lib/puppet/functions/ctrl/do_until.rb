# frozen_string_literal: true

# Repeat the block until it returns a truthy value. Returns the value.
Puppet::Functions.create_function(:'ctrl::do_until') do
  # @example Run a task until it succeeds
  #   ctrl::do_until() || {
  #     run_task('test', $target, _catch_errors => true).ok()
  #   }
  dispatch :do_until do
    optional_param 'Integer', :limit
    block_param
  end

  def do_until(limit)
    i=0
    limit ||= 0
    until (x = yield)
     i = i+1
     next if limit==0
     break if i >= limit
    end
    return x
  end
end
