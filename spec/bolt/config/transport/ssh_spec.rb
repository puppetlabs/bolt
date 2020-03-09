# frozen_string_literal: true

require 'spec_helper'
require 'bolt/config/transport/ssh'
require 'shared_examples/transport_config'

describe Bolt::Config::Transport::SSH do
  let(:transport) { Bolt::Config::Transport::SSH }
  let(:data) { { 'user' => 'bolt' } }
  let(:merge_data) { { 'password' => 'bolt' } }

  include_examples 'transport config'
  include_examples 'filters options'

  context 'using plugins' do
    let(:plugin_data)   { { 'password' => { '_plugin' => 'foo' } } }
    let(:resolved_data) { { 'password' => 'foo' } }

    include_examples 'plugins'
  end

  context 'validating' do
    include_examples 'interpreters'
    include_examples 'sudoable'

    %w[host-key-check load-config tty].each do |opt|
      it "#{opt} errors with wrong type" do
        data[opt] = 'true'
        expect { transport.new(data) }.to raise_error(Bolt::ValidationError)
      end
    end

    %w[connect-timeout disconnect-timeout].each do |opt|
      it "#{opt} errors with wrong type" do
        data[opt] = '100'
        expect { transport.new(data) }.to raise_error(Bolt::ValidationError)
      end
    end

    %w[host password proxyjump run-as script-dir sudo-executable sudo-password tmpdir user].each do |opt|
      it "#{opt} errors with wrong type" do
        data[opt] = 100
        expect { transport.new(data) }.to raise_error(Bolt::ValidationError)
      end
    end

    context 'private-key' do
      it 'errors with wrong type' do
        data['private-key'] = ['/path/to/key']
        expect { transport.new(data) }.to raise_error(Bolt::ValidationError)
      end

      it 'errors when missing key-data' do
        data['private-key'] = { 'data' => 'my_private_key' }
        expect { transport.new(data) }.to raise_error(Bolt::ValidationError)
      end

      it 'expands path relative to Boltdir' do
        allow(Bolt::Util).to receive(:validate_file).and_return(true)
        data['private-key'] = 'path/to/key'
        config = transport.new(data, boltdir)
        expect(config['private-key']).to eq(File.expand_path('path/to/key', boltdir))
      end
    end
  end
end
