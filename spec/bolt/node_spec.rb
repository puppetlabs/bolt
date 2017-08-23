require 'spec_helper'
require 'bolt/node'

describe Bolt::Node do
  describe "with winrm" do
    it "accepts 'winrm://host:port'" do
      uri = Bolt::Node.parse_uri('winrm://neptune:55985')
      expect(uri.scheme).to eq('winrm')
      expect(uri.host).to eq('neptune')
      expect(uri.port).to eq(55985)
    end

    it "defaults the winrm port to 5985" do
      uri = Bolt::Node.parse_uri('winrm://neptune')
      expect(uri.scheme).to eq('winrm')
      expect(uri.host).to eq('neptune')
      expect(uri.port).to eq(5985)
    end
  end

  describe "with ssh" do
    it "accepts 'ssh://host:port'" do
      uri = Bolt::Node.parse_uri('ssh://pluto:2224')
      expect(uri.scheme).to eq('ssh')
      expect(uri.host).to eq('pluto')
      expect(uri.port).to eq(2224)
    end

    it "defaults the ssh port to 22" do
      uri = Bolt::Node.parse_uri('ssh://pluto')
      expect(uri.scheme).to eq('ssh')
      expect(uri.host).to eq('pluto')
      expect(uri.port).to eq(22)
    end

    it "accepts 'host:port' without a scheme" do
      uri = Bolt::Node.parse_uri('pluto:2224')
      expect(uri.scheme).to eq('ssh')
      expect(uri.host).to eq('pluto')
      expect(uri.port).to eq(2224)
    end

    it "defaults the ssh port to 22 without a scheme" do
      uri = Bolt::Node.parse_uri('pluto')
      expect(uri.scheme).to eq('ssh')
      expect(uri.host).to eq('pluto')
      expect(uri.port).to eq(22)
    end
  end
end
