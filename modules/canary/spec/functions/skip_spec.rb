# frozen_string_literal: true

require 'spec_helper'
require 'bolt/inventory'
require 'bolt/result'
require 'bolt/result_set'

describe 'canary::skip' do
  let(:inventory) { Bolt::Inventory.empty }
  let(:target) { inventory.get_target("target1") }
  let(:result) do
    Bolt::Result.new(target, error: {
                       'msg' => "Skipped #{target.name} because of a previous failure",
                       'kind' => 'canary/skipped-target',
                       'details' => {}
                     })
  end

  it 'accepts a target' do
    is_expected.to run.with_params([target]).and_return(Bolt::ResultSet.new([result]))
  end

  it 'accepts a target uri' do
    is_expected.to run.with_params([target.uri]).and_return(Bolt::ResultSet.new([result]))
  end
end
