# frozen_string_literal: true

Puppet::Functions.create_function(:'results::make_apply_result') do
  dispatch :create do
    param 'String', :uri
    param 'Hash', :value
    return_type 'ApplyResult'
  end

  def create(uri, value)
    target = Bolt::Target.new(uri)
    Bolt::ApplyResult.new(target, error: value['_error'], report: value['report'])
  end
end
