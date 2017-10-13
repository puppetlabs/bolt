require 'spec_helper'
require 'bolt/node_uri'

describe Bolt::NodeURI do
  describe "with winrm" do
    it "accepts 'winrm://host:port'" do
      uri = Bolt::NodeURI.new('winrm://neptune:55985')
      expect(uri.scheme).to eq('winrm')
      expect(uri.hostname).to eq('neptune')
      expect(uri.port).to eq(55985)
    end

    it "defaults the winrm port to 5985" do
      uri = Bolt::NodeURI.new('winrm://neptune')
      expect(uri.scheme).to eq('winrm')
      expect(uri.hostname).to eq('neptune')
      expect(uri.port).to eq(5985)
    end
  end

  describe "with ssh" do
    it "accepts 'ssh://host:port'" do
      uri = Bolt::NodeURI.new('ssh://pluto:2224')
      expect(uri.scheme).to eq('ssh')
      expect(uri.hostname).to eq('pluto')
      expect(uri.port).to eq(2224)
    end

    it "does not default the ssh port" do
      uri = Bolt::NodeURI.new('ssh://pluto')
      expect(uri.scheme).to eq('ssh')
      expect(uri.hostname).to eq('pluto')
      expect(uri.port).to be_nil
    end

    it "accepts 'host:port' without a scheme" do
      uri = Bolt::NodeURI.new('pluto:2224')
      expect(uri.scheme).to eq('ssh')
      expect(uri.hostname).to eq('pluto')
      expect(uri.port).to eq(2224)
    end

    it "does not default the ssh port without a scheme" do
      uri = Bolt::NodeURI.new('pluto')
      expect(uri.scheme).to eq('ssh')
      expect(uri.hostname).to eq('pluto')
      expect(uri.port).to be_nil
    end
  end

  describe "with pcp" do
    it "accepts 'pcp://pluto:666'" do
      uri = Bolt::NodeURI.new('pcp://pluto:666')
      expect(uri.scheme).to eq('pcp')
      expect(uri.hostname).to eq('pluto')
      expect(uri.port).to eq(666)
    end

    it "accepts 'pcp://pluto' without a port" do
      uri = Bolt::NodeURI.new('pcp://pluto')
      expect(uri.scheme).to eq('pcp')
      expect(uri.hostname).to eq('pluto')
      expect(uri.port).to be_nil
    end
  end
end
