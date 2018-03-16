# frozen_string_literal: true

Puppet::Functions.create_function(:'results::make_result_set') do
  dispatch :create do
    param 'Hash', :input
    return_type 'ResultSet'
  end

  def create(input)
    results = input.map do |uri, result|
      target = Bolt::Target.new(uri)
      Bolt::Result.new(target, value: result)
    end
    Bolt::ResultSet.new(results)
  end
end
