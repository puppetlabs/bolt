# frozen_string_literal: true

require 'spec_helper'
require 'bolt/target'
require 'bolt/inventory'
require 'bolt/plugin'
require 'bolt/config'

describe Bolt::Target do
  describe "when parsing userinfo" do
    let(:inventory) { Bolt::Inventory.empty }
    let(:user)     { 'gunther' }
    let(:password) { 'foobar' }
    let(:complex)  { '~%F3/-w@ho!#$%^* ' }
    let(:test_name) { 'foo' }

    it "accepts userinfo when a port is specified" do
      target = inventory.get_target("ssh://#{user}:#{password}@neptune:2222")
      expect(target.user).to eq(user)
      expect(target.password).to eq(password)
    end

    it "accepts userinfo without a port" do
      target = inventory.get_target("ssh://#{user}:#{password}@neptune")
      expect(target.user).to eq(user)
      expect(target.password).to eq(password)
    end

    it "accepts userinfo when not specifying a scheme" do
      target = inventory.get_target("#{user}:#{password}@neptune")
      expect(target.user).to eq(user)
      expect(target.password).to eq(password)
    end

    it "defaults user from options" do
      target_hash = { 'name' => 'neptune', 'config' => { 'ssh' => { 'user' => complex } } }
      target = inventory.create_target_from_hash(target_hash)
      expect(target.user).to eq(complex)
    end

    it "defaults password from options" do
      target_hash = { 'name' => 'neptune', 'config' => { 'ssh' => { 'password' => complex } } }
      target = inventory.create_target_from_hash(target_hash)
      expect(target.password).to eq(complex)
    end

    it "defaults port from options" do
      target_hash = { 'name' => 'neptune', 'config' => { 'ssh' => { 'port' => 1234 } } }
      target = inventory.create_target_from_hash(target_hash)
      expect(target.port).to eq(1234)
    end

    it "rejects unescaped special characters" do
      expect {
        inventory.get_target("#{user}:a/b@neptune")
      }.to raise_error(Bolt::ParseError,
                       /Invalid port number/)
    end

    it "accepts escaped special characters in password" do
      table = {
        "\n" => '%0A',
        ' ' => '%20',
        '!' => '!',
        '"' => '%22',
        '#' => '%23',
        '$' => '$',
        '%' => '%25',
        '&' => '&',
        '\'' => '\'',
        '(' => '(',
        ')' => ')',
        '*' => '*',
        '+' => '+',
        '-' => '-',
        '.' => '.',
        '/' => '%2F',
        '0' => '0',
        ':' => '%3A',
        ';' => ';',
        '<' => '%3C',
        '=' => '=',
        '>' => '%3E',
        '?' => '%3F',
        '@' => '@',
        'A' => 'A',
        '[' => '%5B',
        '\\' => '%5C',
        ']' => '%5D',
        '^' => '%5E',
        '_' => '%5F',
        '`' => '%60'
      }
      unencoded = +''
      encoded = +''
      table.each_pair do |k, v|
        unencoded.concat(k)
        encoded.concat(v)
      end

      target = inventory.create_target_from_hash('name' => 'foo', 'uri' => "#{encoded}:#{encoded}@neptune")
      expect(target.user).to eq(unencoded)
      expect(target.password).to eq(unencoded)
    end

    it "does not default the port without a scheme" do
      target = inventory.get_target('pluto')
      expect(target.host).to eq('pluto')
      expect(target.port).to be_nil
    end

    it "does not print password when converted to string" do
      target = inventory.get_target("ssh://#{user}:#{password}@neptune:2222")
      expect(target.to_s).to eq("ssh://#{user}@neptune:2222")
    end

    it "returns the transport" do
      target = inventory.get_target('ssh://jupiter')
      expect(target.transport).to eq('ssh')
    end

    it "returns the transport config" do
      transport_config = Bolt::Config::Transport::SSH.new
      target = inventory.get_target('ssh://jupiter')
      expect(target.transport_config).to eq(transport_config.to_h)
    end

    describe "with winrm" do
      it "accepts 'winrm://host:port'" do
        target = inventory.get_target('winrm://neptune:55985')
        expect(target.transport).to eq('winrm')
        expect(target.host).to eq('neptune')
        expect(target.port).to eq(55985)
      end
    end

    describe "with ssh" do
      it "accepts 'ssh://host:port'" do
        target = inventory.get_target('ssh://pluto:2224')
        expect(target.transport).to eq('ssh')
        expect(target.host).to eq('pluto')
        expect(target.port).to eq(2224)
      end

      it "does not default the ssh port" do
        target = inventory.get_target('ssh://pluto')
        expect(target.transport).to eq('ssh')
        expect(target.host).to eq('pluto')
        expect(target.port).to be_nil
      end

      it "accepts 'host:port' without a scheme" do
        target = inventory.get_target('pluto:2224')
        expect(target.transport).to eq('ssh')
        expect(target.host).to eq('pluto')
        expect(target.port).to eq(2224)
      end
    end

    describe "with pcp" do
      it "accepts 'pcp://pluto:666'" do
        target = inventory.get_target('pcp://pluto:666')
        expect(target.transport).to eq('pcp')
        expect(target.host).to eq('pluto')
        expect(target.port).to eq(666)
      end

      it "accepts 'pcp://pluto' without a port" do
        target = inventory.get_target('pcp://pluto')
        expect(target.transport).to eq('pcp')
        expect(target.host).to eq('pluto')
        expect(target.port).to be_nil
      end
    end

    it "strips brackets from ipv6 addresses in a uri" do
      target = inventory.get_target('ssh://[::1]:22')
      expect(target.host).to eq('::1')
    end

    it 'can have an empty uri' do
      t1 = inventory.create_target_from_hash('name' => 'name1')
      expect(t1.host).to be(nil)
      expect(t1.name).to be('name1')
      expect(t1.uri).to be(nil)
      expect(t1.password).to be(nil)
      expect(t1.user).to be(nil)
      expect(t1.port).to be(nil)
    end

    it 'returns set object with feature_set' do
      target = inventory.get_target('ssh://[::1]:22')
      expect(target.feature_set).to be_a(Set)
    end

    it 'can compare targets' do
      target = inventory.get_target('target')
      other = inventory.get_target('other')
      expect(target.eql?(target)).to eq(true)
      expect(target.eql?(other)).to eq(false)
    end
  end
end
