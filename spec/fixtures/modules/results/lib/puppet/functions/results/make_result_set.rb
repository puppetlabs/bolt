# frozen_string_literal: true

Puppet::Functions.create_function(:'results::make_result_set') do
  dispatch :create do
    param 'Hash', :input
    return_type 'ResultSet'
  end

  def create(input)
    results = input.map do |uri, result|
      inventory = Puppet.lookup(:bolt_inventory)
      inventory.get_target(uri)
      target = Bolt::Target.new(uri, inventory)
      Bolt::Result.new(target, value: result)
    end
    Bolt::ResultSet.new(results)
  end
end
