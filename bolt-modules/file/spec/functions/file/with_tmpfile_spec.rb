# frozen_string_literal: true

require 'spec_helper'

describe 'file::with_tmpfile' do
  it do
    is_expected.to run
      .with_params('foo')
      .with_lambda { |_| 'bar' }
      .and_return('bar')
  end
end
