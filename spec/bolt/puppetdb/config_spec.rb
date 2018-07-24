# frozen_string_literal: true

require 'spec_helper'
require 'bolt/puppetdb/config'
require 'bolt/util'

describe Bolt::PuppetDB::Config do
  context "when validating that options" do
    let(:cacert) { File.expand_path('/path/to/cacert') }
    let(:token) { File.expand_path('/path/to/token') }
    let(:cert) { File.expand_path('/path/to/cert') }
    let(:key) { File.expand_path('/path/to/key') }
    let(:options) do
      {
        'server_urls' => ['https://puppetdb:8081'],
        'cacert'      => cacert,
        'token'       => token,
        'cert'        => cert,
        'key'         => key
      }
    end

    let(:config) { Bolt::PuppetDB::Config.new(options) }

    context "#uri" do
      it 'uses server_urls value if it is a string' do
        expect(config.uri).to eq(URI.parse('https://puppetdb:8081'))
      end

      it 'uses the first item of server_urls when it is an array' do
        options['server_urls'] = ['https://puppetdb:8081', 'https://shmuppetdb:8082']
        expect(config.uri).to eq(URI.parse('https://puppetdb:8081'))
      end

      it 'fails if server_urls is not set' do
        options.delete('server_urls')
        expect { config.uri }.to raise_error(Bolt::PuppetDBError, /server_urls must be specified/)
      end
    end

    context "token" do
      before :each do
        allow(File).to receive(:read).with(token).and_return 'footoken'
        allow(File).to receive(:read).with(Bolt::PuppetDB::Config::DEFAULT_TOKEN).and_return 'bartoken'
      end

      it 'loads the token file if one was specified' do
        expect(config.token).to eq('footoken')
      end

      it 'loads the default token if no file was specified' do
        allow(File).to receive(:exist?).with(Bolt::PuppetDB::Config::DEFAULT_TOKEN).and_return true
        options.delete('token')

        expect(config.token).to eq('bartoken')
      end

      it 'returns nil if no file was specified and the default does not exist' do
        allow(File).to receive(:exist?).with(Bolt::PuppetDB::Config::DEFAULT_TOKEN).and_return false
        options.delete('token')

        expect(config.token).to be_nil
      end
    end

    context "cacert" do
      it 'returns the cacert if it is set and exists' do
        allow(config).to receive(:validate_file_exists).with('cacert').and_return true

        expect(config.cacert).to eq(cacert)
      end

      it 'fails if the cacert is not set' do
        options.delete('cacert')

        expect { config.cacert }.to raise_error(Bolt::PuppetDBError, /cacert must be specified/)
      end

      it 'fails if the cacert does not exist' do
        allow(File).to receive(:exist?).with(cacert).and_return false

        expect { config.cacert }.to raise_error(Bolt::PuppetDBError, /cacert file .* does not exist/)
      end
    end

    context "cert" do
      it 'fails if cert is set but key is not set' do
        options.delete('key')

        expect { config.cert }.to raise_error(Bolt::PuppetDBError, /cert and key must be specified together/)
      end

      it 'returns nil if cert and key are both nil' do
        options.delete('cert')
        options.delete('key')

        expect(config.cert).to be_nil
      end

      it 'returns cert if cert and key are both set' do
        allow(config).to receive(:validate_file_exists).with('cert').and_return true

        expect(config.cert).to eq(cert)
      end

      it 'fails if the cert does not exist' do
        allow(File).to receive(:exist?).with(cert).and_return false

        expect { config.cert }.to raise_error(Bolt::PuppetDBError, /cert file .* does not exist/)
      end
    end

    context "key" do
      it 'fails if key is set but cert is not set' do
        options.delete('cert')

        expect { config.key }.to raise_error(Bolt::PuppetDBError, /cert and key must be specified together/)
      end

      it 'returns nil if cert and key are both nil' do
        options.delete('cert')
        options.delete('key')

        expect(config.key).to be_nil
      end

      it 'returns key if cert and key are both set' do
        allow(config).to receive(:validate_file_exists).with('key').and_return true

        expect(config.key).to eq(key)
      end

      it 'fails if the key does not exist' do
        allow(File).to receive(:exist?).with(key).and_return false

        expect { config.key }.to raise_error(Bolt::PuppetDBError, /key file .* does not exist/)
      end
    end
  end

  context "::load_config" do
    let(:user_supplied) { File.join('test', 'file') }

    it "loads from specified filename when given" do
      expect(File).to receive(:exist?).with(user_supplied)
      expect { Bolt::PuppetDB::Config.load_config(user_supplied, {}) }.to raise_error(/does not exist/)
    end

    it "on non-windows OS loads from default location when filename is nil" do
      allow(Bolt::Util).to receive(:windows?).and_return(false)
      expect(File).to receive(:exist?).with(Bolt::PuppetDB::Config::DEFAULT_CONFIG[:user])
      expect(File).to receive(:exist?).with(Bolt::PuppetDB::Config::DEFAULT_CONFIG[:global])
      Bolt::PuppetDB::Config.load_config(nil, {})
    end

    it "on windows OS loads from default location when filename is nil" do
      allow(Bolt::Util).to receive(:windows?).and_return(true)
      expect(File).to receive(:exist?).with(Bolt::PuppetDB::Config::DEFAULT_CONFIG[:user])
      expect(File).to receive(:exist?).with(Bolt::PuppetDB::Config::DEFAULT_CONFIG[:win_global])
      Bolt::PuppetDB::Config.load_config(nil, {})
    end
  end
end
