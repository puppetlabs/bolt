# frozen_string_literal: true

# Splits an array into two groups, where the 1st group is a randomly selected
# sample of the input (of the specified size) and the 2nd group is the remainder.
#
# This function takes 2 parameters:
# * The array to split (Array)
# * The number of items to sample from the array (Integer)
#
# Returns an array of [<sample>, <remainder>].
Puppet::Functions.create_function(:'canary::random_split') do
  dispatch :rand do
    param 'Array', :arr
    param 'Integer', :size
  end

  def rand(arr, size)
    canaries = arr.sample(size)
    rest = arr.reject { |r| canaries.include?(r) }
    [canaries, rest]
  end
end
