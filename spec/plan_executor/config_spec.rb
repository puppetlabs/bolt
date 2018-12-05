# frozen_string_literal: true

require 'spec_helper'
require 'plan_executor/config'

describe PlanExecutor::Config do
  let(:configdir) { File.join(__dir__, '..', 'fixtures', 'api_server_configs') }
  let(:missingconfig) { File.join(configdir, 'non-existent.conf') }
  let(:emptyconfig) { File.join(configdir, 'empty-plan-executor.conf') }
  let(:globalconfig) { File.join(configdir, 'global-plan-executor.conf') }
  let(:requiredconfig) { File.join(configdir, 'required-plan-executor.conf') }
  let(:base_config) { Hocon.load(requiredconfig)['plan-executor'] }

  def build_config(config_file, from_env = false)
    config = PlanExecutor::Config.new
    config.load_file_config(config_file)
    config.load_env_config if from_env
    config.validate
    config
  end

  context 'with full config' do
    let(:config) { build_config(globalconfig) }

    it 'reads host' do
      expect(config.host).to eq('10.0.0.1')
    end

    it 'reads port' do
      expect(config.port).to eq(12345)
    end

    it 'reads loglevel' do
      expect(config.loglevel).to eq('debug')
    end

    it 'reads logfile' do
      expect(config.logfile).to eq('/var/log/global')
    end

    it 'reads whitelist' do
      expect(config.whitelist).to eq(['a'])
    end

    it 'reads ssl-cipher-suites' do
      expect(config.ssl_cipher_suites).to eq(['a'])
    end

    it 'reads workers' do
      expect(config.workers).to eq(3)
    end
  end

  it "accepts only required config" do
    config = build_config(requiredconfig)
    expect(config.host).to eq('127.0.0.1')
    expect(config.port).to be(62659)
    expect(config.loglevel).to eq('notice')
    expect(config.logfile).to eq(nil)
    expect(config.whitelist).to eq(nil)
    expect(config.ssl_cipher_suites).to include('ECDHE-ECDSA-AES256-GCM-SHA384')
    expect(config.modulepath).to eq('spec/fixtures/modules')
    expect(config.workers).to eq(1)
  end

  it "reads ssl keys from config" do
    config = build_config(globalconfig)
    expect(config.ssl_cert).to eq('spec/fixtures/ssl/cert.pem')
    expect(config.ssl_key).to eq('spec/fixtures/ssl/key.pem')
    expect(config.ssl_ca_cert).to eq('spec/fixtures/ssl/ca.pem')
  end

  it "errors when the config file is missing" do
    expect {
      build_config("/non-existent/configfile.conf")
    }.to raise_error(/Could not find service config at/)
  end
  it "errors when a required key is not present" do
    expect {
      PlanExecutor::Config.new.validate
    }.to raise_error(Bolt::ValidationError, /You must configure/)
  end

  it "errors when whitelist is not an array" do
    expect {
      PlanExecutor::Config.new(base_config.merge('whitelist' => 'notanarray')).validate
    }.to raise_error(Bolt::ValidationError, /Configured 'whitelist' must be an array of names/)
  end

  it "errors when ssl-cipher-suites is not an array" do
    expect {
      PlanExecutor::Config.new(base_config.merge('ssl-cipher-suites' => 'notanarray')).validate
    }.to raise_error(Bolt::ValidationError, /Configured 'ssl-cipher-suites' must be an array of cipher suite names/)
  end
  it "errors when workers is not an integer" do
    expect {
      PlanExecutor::Config.new(base_config.merge('workers' => '10')).validate
    }.to raise_error(Bolt::ValidationError, "Configured 'workers' must be a positive integer")
  end

  it "errors when workers is zero" do
    expect {
      PlanExecutor::Config.new(base_config.merge('workers' => 0)).validate
    }.to raise_error(Bolt::ValidationError, "Configured 'workers' must be a positive integer")
  end

  it "errors when workers is negative" do
    expect {
      PlanExecutor::Config.new(base_config.merge('workers' => -1)).validate
    }.to raise_error(Bolt::ValidationError, "Configured 'workers' must be a positive integer")
  end
end
