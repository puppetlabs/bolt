require 'spec_helper'
require 'bolt'
require 'bolt/node'

describe Bolt::Node do
  describe "initializing nodes from uri" do
    it "understands user and password" do
      node = Bolt::Node.from_uri('ssh://iuyergkj:123456@whitehouse.gov')
      expect(node.user).to eq('iuyergkj')
      expect(node.password).to eq('123456')
    end

    it "defaults to globally set user and password" do
      config = { user: 'somebody',
                 password: 'very secure' }
      allow(Bolt).to receive(:config).and_return(config)

      node = Bolt::Node.from_uri('ssh://localhost')
      expect(node.user).to eq('somebody')
      expect(node.password).to eq('very secure')
    end

    it "uri overrides global user and password" do
      config = { user: 'somebody',
                 password: 'very secure' }
      allow(Bolt).to receive(:config).and_return(config)

      node = Bolt::Node.from_uri('ssh://toor:better@localhost')
      expect(node.user).to eq('toor')
      expect(node.password).to eq('better')
    end

    it "strips brackets from ipv6 addresses in a uri" do
      expect(Bolt::SSH).to receive(:new).with('::1', any_args)

      Bolt::Node.from_uri('ssh://[::1]:22')
    end
  end
end
