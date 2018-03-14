# frozen_string_literal: true

require 'spec_helper'
require 'bolt/target'
require 'bolt/result'
require 'bolt/result_set'

describe 'canary::merge' do
  def make_result(uri)
    target = Bolt::Target.new(uri)
    Bolt::Result.new(target, message: "ran on #{uri}")
  end

  it 'can merge two resultspecs' do
    r1 = %w[node1 node2].map { |u| make_result(u) }
    r2 = ["node3"].map { |u| make_result(u) }

    expected = Bolt::ResultSet.new(r1 + r2)

    is_expected.to run.with_params(Bolt::ResultSet.new(r1), Bolt::ResultSet.new(r2)).and_return(expected)
  end
end
