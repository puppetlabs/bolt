# frozen_string_literal: true

require 'spec_helper'
require 'bolt/puppetdb/config'

describe Bolt::PuppetDB::Config do
  let(:config_file) { nil }
  let(:config) { Bolt::PuppetDB::Config.new(config_file, @options) }
  let(:options) do
    {
      'server_urls' => ['https://puppetdb:8081'],
      'cacert' => '/path/to/cacert',
      'token' => '/path/to/token',
      'cert' => '/path/to/cert',
      'key' => '/path/to/key'
    }
  end

  before :each do
    allow_any_instance_of(Bolt::PuppetDB::Config).to receive(:load_config).and_return({})
    allow_any_instance_of(Bolt::PuppetDB::Config).to receive(:validate_file_exists)
  end

  describe "#validate" do
    it "fails if no url is set" do
      options.delete('server_urls')

      expect { described_class.new(config_file, options) }.to raise_error(/server_urls must be specified/)
    end

    it "fails if no cacert is set" do
      options.delete('cacert')

      expect { described_class.new(config_file, options) }.to raise_error(/cacert must be specified/)
    end

    it "accepts only a token with cert/key" do
      options.delete('cert')
      options.delete('key')

      expect { described_class.new(config_file, options) }.not_to raise_error
    end

    it "accepts a cert and key without a token" do
      options.delete('token')

      expect { described_class.new(config_file, options) }.not_to raise_error
    end

    it "fails if only cert and no key is specified" do
      options.delete('key')

      expect { described_class.new(config_file, options) }.to raise_error(/cert and key must be specified together/)
    end

    it "fails if only key and no cert is specified" do
      options.delete('cert')

      expect { described_class.new(config_file, options) }.to raise_error(/cert and key must be specified together/)
    end
  end
end
