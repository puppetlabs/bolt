# frozen_string_literal: true

require 'spec_helper'

describe 'ctrl::do_until' do
  let(:seq) { [false, 'truthy', false, false] }

  it 'stops with a truth value' do
    is_expected.to(run.with_lambda do
      seq.pop
    end.and_return('truthy'))
  end

  it 'does not stop with limit 0' do
    is_expected.to(run.with_params('limit' => 0).with_lambda do
      seq.pop
    end.and_return('truthy'))
    expect(seq.length).to eq(1)
  end

  it 'exits early with a limit' do
    is_expected.to(run.with_params('limit' => 2).with_lambda do
      seq.pop
    end.and_return(false))
    expect(seq.length).to eq(2)
  end

  it 'returns the correct value with a larger limit' do
    is_expected.to(run.with_params('limit' => 3).with_lambda do
      seq.pop
    end.and_return("truthy"))
    expect(seq.length).to eq(1)
  end
end
