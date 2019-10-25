# frozen_string_literal: true

require 'spec_helper'
require 'bolt/plugin/prompt'
require 'io/console'

describe Bolt::Plugin::Prompt do
  let(:prompt_data) { { '_plugin' => 'prompt', 'message' => 'Password Please' } }
  let(:invalid_prompt_data) { { '_plugin' => 'prompt' } }
  let(:password) { 'opensesame' }
  after(:each) do
    # rubocop:disable Style/GlobalVars
    $future = nil
    # rubocop:enable Style/GlobalVars
  end

  it 'raises a validation error when no prompt message is provided' do
    expect { subject.validate_resolve_reference(invalid_prompt_data) }.to raise_error(Bolt::ValidationError)
  end

  it 'concurrent delay prompts for data on STDOUT when executed' do
    allow(STDIN).to receive(:noecho).and_return(password)
    allow(STDOUT).to receive(:puts)
    expect(STDOUT).to receive(:print).with("#{prompt_data['message']}:")

    val = subject.resolve_reference(prompt_data)
    expect(val).to eq(password)
  end

  it 'concurrent delay prompts for data on STDERR when executed with $future flag set' do
    # rubocop:disable Style/GlobalVars
    $future = true
    # rubocop:enable Style/GlobalVars

    allow(STDIN).to receive(:noecho).and_return(password)
    allow(STDERR).to receive(:puts)
    expect(STDERR).to receive(:print).with("#{prompt_data['message']}:")

    val = subject.resolve_reference(prompt_data)
    expect(val).to eq(password)
  end
end
