Puppet::Functions.create_function(:'results::make_result') do
  dispatch :create do
    param 'String', :uri
    param 'Hash', :value
    return_type 'Result'
  end

  def create(uri, value)
    target = Bolt::Target.new(uri)
    Bolt::Result.new(target, value: value)
  end
end
