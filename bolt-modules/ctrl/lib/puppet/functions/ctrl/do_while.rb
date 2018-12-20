# frozen_string_literal: true

# Repeat the block while it returns 'true'.
Puppet::Functions.create_function(:'ctrl::do_while') do
  # @example Run a task while it succeeds
  #   ctrl::do_while || {
  #     run_task('intermittent_failure', $target, _catch_errors => true).ok?
  #   }
  dispatch :do_while do
    block_param
    return_type 'Undef'
  end

  def do_while
    while yield; end
    nil
  end
end
