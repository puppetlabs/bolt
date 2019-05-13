Puppet::Functions.create_function(:unique) do
  dispatch :unique do
    param 'Array[Data]', :vals
  end

  def unique(vals)
    vals.uniq
  end
end
