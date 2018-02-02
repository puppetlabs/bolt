require 'spec_helper'
require 'json'
require 'bolt'
require 'bolt/target'
require 'bolt/node'

def from_uri(uri, config)
  Bolt::Node.from_target(Bolt::Target.from_uri(uri).update_conf(config))
end

describe Bolt::Node do
  describe "initializing nodes from uri" do
    let(:config) { Bolt::Config.new }
    it "understands user and password" do
      node = from_uri('ssh://iuyergkj:123456@whitehouse.gov', config)
      expect(node.user).to eq('iuyergkj')
      expect(node.password).to eq('123456')
      expect(node.uri).to eq('ssh://iuyergkj:123456@whitehouse.gov')
    end

    it "defaults to specified user and password" do
      config[:transports][:ssh][:user] = 'somebody'
      config[:transports][:ssh][:password] = 'very secure'
      node = from_uri('ssh://localhost', config)
      expect(node.user).to eq('somebody')
      expect(node.password).to eq('very secure')
    end

    it "uri overrides specified user and password" do
      config[:transports][:ssh][:user] = 'somebody'
      config[:transports][:ssh][:password] = 'very secure'
      node = from_uri('ssh://toor:better@localhost', config)
      expect(node.user).to eq('toor')
      expect(node.password).to eq('better')
    end
  end
end
