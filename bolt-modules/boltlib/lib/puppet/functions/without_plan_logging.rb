# frozen_string_literal: true

Puppet::Functions.create_function(:without_plan_logging) do
  dispatch :without_plan_logging do
    block_param 'Callable[0, 0]', :block
  end

  def without_plan_logging(&block)
    executor = Puppet.lookup(:bolt_executor) { nil }
    old_log = executor.plan_logging
    executor.plan_logging = false
    begin
      block.call
    ensure
      executor.plan_logging = old_log
    end
  end
end
