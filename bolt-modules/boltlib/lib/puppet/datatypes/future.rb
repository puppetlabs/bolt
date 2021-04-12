# frozen_string_literal: true

# The [`background()` plan function](plan_functions.md#background) returns a
# `Future` object, which can be passed to the [`wait()` plan
# function](plan_functions.md#wait) to block on the result of the backgrounded
# code block.
#
# @!method state
#   Either 'running' if the Future is still executing, 'done' if the Future
#   finished successfully, or 'error' if the Future finished with an error.
#
Puppet::DataTypes.create_type('Future') do
  interface <<-PUPPET
    attributes => {},
    functions => {
      state => Callable[[], Enum['running', 'done', 'error']],
    }
  PUPPET

  load_file('bolt/plan_future')

  # Needed for Puppet to recognize Bolt::Result as a Puppet object when deserializing
  Bolt::PlanFuture.include(Puppet::Pops::Types::PuppetObject)
  implementation_class Bolt::PlanFuture
end
