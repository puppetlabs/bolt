# frozen_string_literal: true

require 'spec_helper'

describe 'coll::group_by' do
  it { is_expected.to run.with_params(%w[a b ab]).with_lambda(&:length).and_return(1 => %w[a b], 2 => %w[ab]) }
  it do
    is_expected.to run.with_params('a' => [1, 2], 'b' => [1])
                      .with_lambda { |_k, v| v.length }
                      .and_return(1 => [['b', [1]]], 2 => [['a', [1, 2]]])
  end
end
