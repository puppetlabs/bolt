# frozen_string_literal: true

require 'spec_helper'

describe 'coll::partition' do
  it { is_expected.to run.with_params(['', 'b', 'c']).with_lambda(&:empty?).and_return([[''], %w[b c]]) }
  it do
    is_expected.to run.with_params('a' => [1, 2], 'b' => [])
                      .with_lambda { |_k, v| v.empty? }
                      .and_return([[['b', []]], [['a', [1, 2]]]])
  end
end
