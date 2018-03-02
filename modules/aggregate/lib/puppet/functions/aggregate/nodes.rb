# Aggregates the key/value pairs in the results of a ResultSet into a hash
# mapping the keys to a hash of each distinct value and the list of nodes
# returning that value for the key.
Puppet::Functions.create_function(:'aggregate::nodes') do
  dispatch :aggregate_nodes do
    param 'ResultSet', :resultset
  end

  def aggregate_nodes(resultset)
    resultset.each_with_object({}) do |result, agg|
      result.value.each do |key, val|
        agg[key] ||= {}
        agg[key][val.to_s] ||= []
        agg[key][val.to_s] << result.target.name
      end
      agg
    end
  end
end
