# frozen_string_literal: true

require 'spec_helper'
require 'bolt_server/config'

describe BoltServer::Config do
  let(:configdir) { File.join(__dir__, '..', 'fixtures', 'api_server_configs') }
  let(:missingconfig) { File.join(configdir, 'non-existent.conf') }
  let(:emptyconfig) { File.join(configdir, 'empty-bolt-server.conf') }
  let(:globalconfig) { File.join(configdir, 'global-bolt-server.conf') }
  let(:requiredconfig) { File.join(configdir, 'required-bolt-server.conf') }
  let(:base_config) { Hocon.load(requiredconfig)['bolt-server'] }

  def build_config(config_file, from_env = false)
    config = BoltServer::Config.new
    config.load_file_config(config_file)
    config.load_env_config if from_env
    config.validate
    config
  end

  context 'with full config' do
    let(:config) { build_config(globalconfig) }

    it 'reads host' do
      expect(config['host']).to eq('10.0.0.1')
    end

    it 'reads port' do
      expect(config['port']).to eq(12345)
    end

    it 'reads loglevel' do
      expect(config['loglevel']).to eq('debug')
    end

    it 'reads logfile' do
      expect(config['logfile']).to eq('/var/log/global')
    end

    it 'reads whitelist' do
      expect(config['whitelist']).to eq(['a'])
    end

    it 'reads ssl-cipher-suites' do
      expect(config['ssl-cipher-suites']).to eq(['a'])
    end

    it 'reads concurrency' do
      expect(config['concurrency']).to eq(12)
    end
  end

  context 'with configuation parameters set in environment variables' do
    def transform_key(key)
      "BOLT_#{key.tr('-', '_').upcase}"
    end

    before(:context) do
      empty = BoltServer::Config.new
      empty.env_keys.each do |key|
        transformed_key = transform_key(key)
        ENV[transformed_key] = if empty.int_keys.include?(key)
                                 '23'
                               else
                                 __FILE__
                               end
      end
    end

    let(:fake_env_config) { __FILE__ }
    let(:config) { build_config(globalconfig, true) }

    after(:context) do
      BoltServer::Config.new.env_keys.each do |key|
        ENV.delete(transform_key(key))
      end
    end

    it 'reads ssl-cert ' do
      expect(config['ssl-cert']).to eq(fake_env_config)
    end

    it 'reads ssl-key' do
      expect(config['ssl-key']).to eq(fake_env_config)
    end

    it 'reads ssl-ca-cert' do
      expect(config['ssl-ca-cert']).to eq(fake_env_config)
    end

    it 'reads loglevel' do
      expect(config['loglevel']).to eq(fake_env_config)
    end

    it 'reads concurrency' do
      expect(config['concurrency']).to eq(23)
    end

    it 'reads file-server-conn-timeout' do
      expect(config['file-server-conn-timeout']).to eq(23)
    end

    it 'reads file-server-uri' do
      expect(config['file-server-uri']).to eq(fake_env_config)
    end
  end

  it "accepts only required config" do
    config = build_config(requiredconfig)
    expect(config['host']).to eq('127.0.0.1')
    expect(config['port']).to be(62658)
    expect(config['loglevel']).to eq('notice')
    expect(config['logfile']).to eq(nil)
    expect(config['whitelist']).to eq(nil)
    expect(config['ssl-cipher-suites']).to include('ECDHE-ECDSA-AES256-GCM-SHA384')
    expect(config['concurrency']).to eq(100)
  end

  it "reads ssl keys from config" do
    config = build_config(globalconfig)
    expect(config['ssl-cert']).to eq('spec/fixtures/ssl/cert.pem')
    expect(config['ssl-key']).to eq('spec/fixtures/ssl/key.pem')
    expect(config['ssl-ca-cert']).to eq('spec/fixtures/ssl/ca.pem')
  end

  it "errors when the config file is missing" do
    expect {
      build_config("/non-existent/configfile.conf")
    }.to raise_error(/Could not find service config at/)
  end

  it "errors when a required key is not present" do
    expect {
      BoltServer::Config.new.validate
    }.to raise_error(Bolt::ValidationError, /You must configure/)
  end

  it "errors when whitelist is not an array" do
    expect {
      BoltServer::Config.new(base_config.merge('whitelist' => 'notanarray')).validate
    }.to raise_error(Bolt::ValidationError, /Configured 'whitelist' must be an array of names/)
  end

  it "errors when ssl-cipher-suites is not an array" do
    expect {
      BoltServer::Config.new(base_config.merge('ssl-cipher-suites' => 'notanarray')).validate
    }.to raise_error(Bolt::ValidationError, /Configured 'ssl-cipher-suites' must be an array of cipher suite names/)
  end

  it "errors when concurrency is not an integer" do
    expect {
      BoltServer::Config.new(base_config.merge('concurrency' => '10')).validate
    }.to raise_error(Bolt::ValidationError, "Configured 'concurrency' must be a positive integer")
  end

  it "errors when concurrency is zero" do
    expect {
      BoltServer::Config.new(base_config.merge('concurrency' => 0)).validate
    }.to raise_error(Bolt::ValidationError, "Configured 'concurrency' must be a positive integer")
  end

  it "errors when concurrency is negative" do
    expect {
      BoltServer::Config.new(base_config.merge('concurrency' => -1)).validate
    }.to raise_error(Bolt::ValidationError, "Configured 'concurrency' must be a positive integer")
  end
end
