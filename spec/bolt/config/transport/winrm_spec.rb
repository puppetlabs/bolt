# frozen_string_literal: true

require 'spec_helper'
require 'bolt/config/transport/winrm'
require 'shared_examples/transport_config'

describe Bolt::Config::Transport::WinRM do
  let(:transport) { Bolt::Config::Transport::WinRM }
  let(:data) { { 'user' => 'bolt' } }
  let(:merge_data) { { 'password' => 'bolt' } }

  include_examples 'transport config'
  include_examples 'filters options'

  context 'using plugins' do
    let(:plugin_data) { { 'password' => { '_plugin' => 'foo' } } }
    let(:resolved_data) { { 'password' => 'foo' } }

    include_examples 'plugins'
  end

  context 'validating' do
    include_examples 'interpreters'

    %w[ssl ssl-verify].each do |opt|
      it "#{opt} errors with wrong type" do
        data[opt] = 'true'
        expect { transport.new(data) }.to raise_error(Bolt::ValidationError)
      end
    end

    %w[cacert file-protocol host password realm tmpdir user basic-auth-only].each do |opt|
      it "#{opt} errors with wrong type" do
        data[opt] = 100
        expect { transport.new(data) }.to raise_error(Bolt::ValidationError)
      end
    end

    it 'connect-timeout errors with wrong type' do
      data['connect-timeout'] = '100'
      expect { transport.new(data) }.to raise_error(Bolt::ValidationError)
    end

    it 'extensions errors with wrong type' do
      data['extensions'] = {}
      expect { transport.new(data) }.to raise_error(Bolt::ValidationError)
    end

    context 'file-protocol' do
      it 'errors when using smb with ssl enabled' do
        data['ssl'] = true
        data['file-protocol'] = 'smb'
        expect { transport.new(data) }.to raise_error(Bolt::ValidationError)
      end
    end

    context 'basic-auth-only' do
      it 'errors when not using ssl' do
        data['ssl'] = false
        data['basic-auth-only'] = true
        expect { transport.new(data) }.to raise_error(Bolt::ValidationError)
      end
    end

    context 'cacert' do
      it 'expands path relative to Boltdir' do
        allow(Bolt::Util).to receive(:validate_file).and_return(true)
        data['cacert'] = 'path/to/cacert'
        config = transport.new(data, boltdir)
        expect(config['cacert']).to eq(File.expand_path('path/to/cacert', boltdir))
      end

      it 'ignores cacert when ssl is false' do
        data['cacert'] = 'path/to/cacert'
        data['ssl']    = false
        expect { transport.new(data) }.not_to raise_error
      end
    end
  end
end
