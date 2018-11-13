# frozen_string_literal: true

require 'spec_helper'
require 'bolt/transport/local'
require 'bolt/target'

require_relative 'shared_examples'

describe Bolt::Transport::Local, bash: true do
  let(:runner) { Bolt::Transport::Local.new }
  let(:os_context) { posix_context }
  let(:transport_conf) { {} }
  let(:target) { Bolt::Target.new('local://localhost', transport_conf) }

  it 'is always connected' do
    expect(runner.connected?(target)).to eq(true)
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
