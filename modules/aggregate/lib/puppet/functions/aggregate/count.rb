# Aggregates the key/value pairs in the results of a ResultSet into a hash
# mapping the keys to a hash of each distinct value and how many nodes returned
# that value for the key.
Puppet::Functions.create_function(:'aggregate::count') do
  dispatch :aggregate_count do
    param 'ResultSet', :resultset
  end

  def aggregate_count(resultset)
    resultset.each_with_object({}) do |result, agg|
      result.value.each do |key, val|
        agg[key] ||= {}
        agg[key][val.to_s] ||= 0
        agg[key][val.to_s] += 1
      end
      agg
    end
  end
end
