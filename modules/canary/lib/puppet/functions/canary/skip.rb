# frozen_string_literal: true

# Returns a ResultSet with canary/skipped-target errors for each Target provided.
#
# This function takes a single parameter:
# * List of targets (Array[Variant[Target,String]])
#
# Returns a ResultSet.
Puppet::Functions.create_function(:'canary::skip') do
  dispatch :skip_result do
    param 'Array[Variant[Target,String]]', :targets
  end

  def skip_result(targets)
    results = targets.map do |target|
      target = Bolt::Target.new(target) unless target.is_a? Bolt::Target
      Bolt::Result.new(target, value: { '_error' => {
                         'msg' => "Skipped #{target.name} because of a previous failure",
                         'kind' => 'canary/skipped-target',
                         'details' => {}
                       } })
    end
    Bolt::ResultSet.new(results)
  end
end
