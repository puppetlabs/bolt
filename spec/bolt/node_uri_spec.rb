require 'spec_helper'
require 'bolt/node_uri'

describe Bolt::NodeURI do
  describe "when parsing userinfo" do
    let(:user)     { 'günther' }
    let(:password) { 'foobar' }

    it "accepts userinfo when a port is specified" do
      uri = Bolt::NodeURI.new("ssh://#{user}:#{password}@neptune:2222")
      expect(uri.user).to eq(user)
      expect(uri.password).to eq(password)
    end

    it "accepts userinfo without a port" do
      uri = Bolt::NodeURI.new("ssh://#{user}:#{password}@neptune")
      expect(uri.user).to eq(user)
      expect(uri.password).to eq(password)
    end

    it "accepts userinfo when using the default scheme" do
      uri = Bolt::NodeURI.new("#{user}:#{password}@neptune")
      expect(uri.user).to eq(user)
      expect(uri.password).to eq(password)
    end

    it "rejects unescaped special characters" do
      expect {
        Bolt::NodeURI.new("#{user}:a/b@neptune")
      }.to raise_error(Addressable::URI::InvalidURIError,
                       /Invalid port number/)
    end

    it "accepts escaped special characters in password" do
      table = {
        "\n" => '%0A',
        ' '  => '%20',
        '!'  => '!',
        '"'  => '%22',
        '#'  => '%23',
        '$'  => '$',
        '%'  => '%25',
        '&'  => '&',
        '\'' => '\'',
        '('  => '(',
        ')'  => ')',
        '*'  => '*',
        '+'  => '+',
        '-'  => '-',
        '.'  => '.',
        '/'  => '%2F',
        '0'  => '0',
        ':'  => '%3A',
        ';'  => ';',
        '<'  => '%3C',
        '='  => '=',
        '>'  => '%3E',
        '?'  => '%3F',
        '@'  => '@',
        'A'  => 'A',
        '['  => '%5B',
        '\\' => '%5C',
        ']'  => '%5D',
        '^'  => '%5E',
        '_'  => '%5F',
        '`'  => '%60'
      }
      unencoded = ''
      encoded = ''
      table.each_pair do |k, v|
        unencoded.concat(k)
        encoded.concat(v)
      end

      uri = Bolt::NodeURI.new("#{encoded}:#{encoded}@neptune")
      expect(uri.user).to eq(unencoded)
      expect(uri.password).to eq(unencoded)
    end
  end

  describe "with winrm" do
    it "accepts 'winrm://host:port'" do
      uri = Bolt::NodeURI.new('winrm://neptune:55985')
      expect(uri.scheme).to eq('winrm')
      expect(uri.hostname).to eq('neptune')
      expect(uri.port).to eq(55985)
    end

    it "uses 'winrm' when it's the default transport" do
      uri = Bolt::NodeURI.new('neptune', 'winrm')
      expect(uri.scheme).to eq('winrm')
      expect(uri.hostname).to eq('neptune')
      expect(uri.port).to be_nil
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

  describe "with unsupported http scheme" do
    it "accepts 'http://pluto:666'" do
      uri = Bolt::NodeURI.new('http://pluto:666')
      expect(uri.scheme).to eq('http')
      expect(uri.hostname).to eq('pluto')
      expect(uri.port).to eq(666)
    end
  end
end
