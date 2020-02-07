# frozen_string_literal: true

Puppet::Functions.create_function(:'results::make_result') do
  dispatch :create do
    param 'String', :uri
    param 'Hash', :value
    return_type 'Result'
  end

  def create(uri, value)
    inventory = Puppet.lookup(:bolt_inventory)
    inventory.get_target(uri)
    target = Bolt::Target.new(uri, inventory)
    Bolt::Result.new(target, value: value)
  end
end
