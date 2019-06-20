# frozen_string_literal: true

require 'spec_helper'
require 'bolt/plugin/prompt'
require 'io/console'

describe Bolt::Plugin::Prompt do
  let(:prompt_data) { { '_plugin' => 'prompt', 'message' => 'Password Please' } }
  let(:invalid_prompt_data) { { '_plugin' => 'prompt' } }
  let(:password) { 'opensesame' }

  it 'has a hook for inventory_config_lookup' do
    expect(subject.hooks).to eq(['inventory_config_lookup'])
  end

  it 'raises a validation error when no prompt message is provided' do
    expect { subject.validate_inventory_config_lookup(invalid_prompt_data) }.to raise_error(Bolt::ValidationError)
  end

  it 'concurrent delay prompts for data when executed' do
    allow(STDIN).to receive(:noecho).and_return(password)
    allow(STDOUT).to receive(:puts)
    expect(STDOUT).to receive(:print).with("#{prompt_data['message']}:")

    val = subject.inventory_config_lookup(prompt_data)
    expect(val).to eq(password)
  end
end
