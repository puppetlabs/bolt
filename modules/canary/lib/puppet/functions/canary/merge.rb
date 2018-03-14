# frozen_string_literal: true

# Merges two ResultSets into a new ResultSet
Puppet::Functions.create_function(:'canary::merge') do
  dispatch :merge_results do
    param 'ResultSet', :merger
    param 'ResultSet', :mergee
  end

  def merge_results(merger, mergee)
    Bolt::ResultSet.new(merger.results + mergee.results)
  end
end
