# frozen_string_literal: true

# Repeat the block until it returns 'true'.
Puppet::Functions.create_function(:'ctrl::do_until') do
  # @example Run a task until it succeeds
  #   ctrl::do_until || {
  #     run_task('test', $target, _catch_errors => true).ok?
  #   }
  dispatch :do_until do
    block_param
    return_type 'Undef'
  end

  def do_until
    until yield; end
    nil
  end
end
