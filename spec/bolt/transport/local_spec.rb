# frozen_string_literal: true

require 'spec_helper'
require 'bolt/transport/local'
require 'bolt/target'
require 'bolt/inventory'
require 'bolt_spec/transport'

require_relative 'shared_examples'

describe Bolt::Transport::Local do
  include BoltSpec::Transport

  let(:transport) { :local }
  let(:os_context) { Bolt::Util.windows? ? windows_context : posix_context }
  let(:target) { Bolt::Target.new('local://localhost', transport_conf) }

  it 'is always connected' do
    expect(runner.connected?(target)).to eq(true)
  end

  it 'provides platform specific features' do
    if Bolt::Util.windows?
      expect(runner.provided_features).to eq(['powershell'])
    else
      expect(runner.provided_features).to eq(['shell'])
    end
  end

  include_examples 'transport api'

  context 'file errors' do
    before(:each) do
      allow(FileUtils).to receive(:cp_r).and_raise('no write')
      allow(Dir).to receive(:mktmpdir).with(no_args).and_raise('no tmpdir')
    end

    include_examples 'transport failures'
  end
end
