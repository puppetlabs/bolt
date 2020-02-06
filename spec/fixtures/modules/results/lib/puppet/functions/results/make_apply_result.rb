# frozen_string_literal: true

Puppet::Functions.create_function(:'results::make_apply_result') do
  dispatch :create do
    param 'String', :uri
    param 'Hash', :value
    return_type 'ApplyResult'
  end

  def create(uri, value)
    inventory = Puppet.lookup(:bolt_inventory)
    target = inventory.get_target(uri)
    Bolt::ApplyResult.new(target, error: value['_error'], report: value['report'])
  end
end
