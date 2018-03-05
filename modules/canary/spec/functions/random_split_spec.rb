require 'spec_helper'
require 'bolt/target'

describe 'canary::random_split' do
  it 'with given host' do
    # Can't test randomness with and_returns
    is_expected.to run.with_params(%w[host1 host2 host3], 1)
  end
end
