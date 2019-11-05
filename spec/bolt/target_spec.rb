# frozen_string_literal: true

require 'spec_helper'
require 'bolt/target'
require 'bolt/inventory'
require 'bolt/plugin'
require 'bolt/config'

describe Bolt::Target do
  describe "when parsing userinfo" do
    let(:user)     { 'günther' }
    let(:password) { 'foobar' }
    let(:complex)  { '~%F3/-w@ho!#$%^* ' }

    it "accepts userinfo when a port is specified" do
      uri = Bolt::Target.new("ssh://#{user}:#{password}@neptune:2222")
      expect(uri.user).to eq(user)
      expect(uri.password).to eq(password)
    end

    it "accepts userinfo without a port" do
      uri = Bolt::Target.new("ssh://#{user}:#{password}@neptune")
      expect(uri.user).to eq(user)
      expect(uri.password).to eq(password)
    end

    it "accepts userinfo when using the default protocol" do
      uri = Bolt::Target.new("#{user}:#{password}@neptune")
      expect(uri.user).to eq(user)
      expect(uri.password).to eq(password)
    end

    it "defaults user from options" do
      uri = Bolt::Target.new("neptune", 'user' => complex)
      expect(uri.user).to eq(complex)
    end

    it "defaults password from options" do
      uri = Bolt::Target.new("neptune", 'password' => complex)
      expect(uri.password).to eq(complex)
    end

    it "defaults port from options" do
      uri = Bolt::Target.new("neptune", 'port' => 1234)
      expect(uri.port).to eq(1234)
    end

    it "rejects unescaped special characters" do
      expect {
        Bolt::Target.new("#{user}:a/b@neptune")
      }.to raise_error(Bolt::ParseError,
                       /Invalid port number/)
    end

    it 'can compare targets' do
      target = Bolt::Target.new('target')
      other = Bolt::Target.new('other')
      target_same_name_foo = Bolt::Target.new(nil, 'name' => 'target')
      target_same_name_bar = Bolt::Target.new(nil, 'name' => 'target')
      other_name = Bolt::Target.new(nil, 'name' => 'other')
      expect(target.eql?(target)).to eq(true)
      expect(target.eql?(other)).to eq(false)
      expect(target_same_name_bar.eql?(target_same_name_foo)).to eq(true)
      expect(target_same_name_foo.eql?(other_name)).to eq(false)
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

      uri = Bolt::Target.new("#{encoded}:#{encoded}@neptune")
      expect(uri.user).to eq(unencoded)
      expect(uri.password).to eq(unencoded)
    end
  end

  it "does not default the port without a protocol" do
    uri = Bolt::Target.new('pluto')
    expect(uri.host).to eq('pluto')
    expect(uri.port).to be_nil
  end

  it "does not print password when converted to string" do
    opts = { 'user' => 'person',
             'password' => 'secret',
             'host' => 'machine',
             'protocol' => 'ssh' }
    target = Bolt::Target.new('example.com', opts)
    expect(target.to_s).to eq("Target('example.com', "\
                              "#{opts.reject { |k, _| k == 'password' }})")
  end

  describe "with winrm" do
    it "accepts 'winrm://host:port'" do
      uri = Bolt::Target.new('winrm://neptune:55985')
      expect(uri.protocol).to eq('winrm')
      expect(uri.host).to eq('neptune')
      expect(uri.port).to eq(55985)
    end
  end

  describe "with ssh" do
    it "accepts 'ssh://host:port'" do
      uri = Bolt::Target.new('ssh://pluto:2224')
      expect(uri.protocol).to eq('ssh')
      expect(uri.host).to eq('pluto')
      expect(uri.port).to eq(2224)
    end

    it "does not default the ssh port" do
      uri = Bolt::Target.new('ssh://pluto')
      expect(uri.protocol).to eq('ssh')
      expect(uri.host).to eq('pluto')
      expect(uri.port).to be_nil
    end

    it "accepts 'host:port' without a protocol" do
      uri = Bolt::Target.new('pluto:2224')
      expect(uri.protocol).to eq(nil)
      expect(uri.host).to eq('pluto')
      expect(uri.port).to eq(2224)
    end
  end

  describe "with pcp" do
    it "accepts 'pcp://pluto:666'" do
      uri = Bolt::Target.new('pcp://pluto:666')
      expect(uri.protocol).to eq('pcp')
      expect(uri.host).to eq('pluto')
      expect(uri.port).to eq(666)
    end

    it "accepts 'pcp://pluto' without a port" do
      uri = Bolt::Target.new('pcp://pluto')
      expect(uri.protocol).to eq('pcp')
      expect(uri.host).to eq('pluto')
      expect(uri.port).to be_nil
    end
  end

  describe "with unsupported http protocol" do
    it "accepts 'http://pluto:666'" do
      uri = Bolt::Target.new('http://pluto:666')
      expect(uri.protocol).to eq('http')
      expect(uri.host).to eq('pluto')
      expect(uri.port).to eq(666)
    end
  end

  it "strips brackets from ipv6 addresses in a uri" do
    uri = Bolt::Target.new('ssh://[::1]:22')
    expect(uri.host).to eq('::1')
  end

  it "can be copied" do
    uri1 = Bolt::Target.new('http://pluto:666')
    uri2 = Bolt::Target.new(uri1.uri)
    expect(uri1).to eq(uri2)
  end

  it 'can have an empty uri' do
    t1 = Bolt::Target.new(nil, 'name' => 'name1')
    expect(t1.host).to be(nil)
    expect(t1.name).to be('name1')
    expect(t1.uri).to be(nil)
    expect(t1.password).to be(nil)
    expect(t1.user).to be(nil)
    expect(t1.protocol).to be(nil)
    expect(t1.port).to be(nil)
  end

  it 'returns set object with feature_set' do
    t1 = Bolt::Target.new(nil, 'name' => 'name1')
    expect(t1.feature_set).to be_a(Set)
  end
end

describe Bolt::Target2 do
  describe "when parsing userinfo" do
    let(:config) { Bolt::Config.new(Bolt::Boltdir.new('.'), {}) }
    let(:pal) { nil }
    let(:plugins) { Bolt::Plugin.setup(config, pal, nil, Bolt::Analytics::NoopClient.new) }
    let(:inventory) { Bolt::Inventory.create_version({ 'version' => 2 }, config, plugins) }
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

    it "accepts userinfo when using the default protocol" do
      target = inventory.get_target("#{user}:#{password}@neptune")
      expect(target.user).to eq(user)
      expect(target.password).to eq(password)
    end

    it "defaults user from options" do
      target_hash = { 'name' => 'neptune', 'config' => { 'ssh' => { 'user' => complex } } }
      target = inventory.create_target_from_plan(target_hash)
      expect(target.user).to eq(complex)
    end

    it "defaults password from options" do
      target_hash = { 'name' => 'neptune', 'config' => { 'ssh' => { 'password' => complex } } }
      target = inventory.create_target_from_plan(target_hash)
      expect(target.password).to eq(complex)
    end

    it "defaults port from options" do
      target_hash = { 'name' => 'neptune', 'config' => { 'ssh' => { 'port' => 1234 } } }
      target = inventory.create_target_from_plan(target_hash)
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

      target = inventory.create_target_from_plan('name' => 'foo', 'uri' => "#{encoded}:#{encoded}@neptune")
      expect(target.user).to eq(unencoded)
      expect(target.password).to eq(unencoded)
    end

    it "does not default the port without a protocol" do
      target = inventory.get_target('pluto')
      expect(target.host).to eq('pluto')
      expect(target.port).to be_nil
    end

    it "does not print password when converted to string" do
      target = inventory.get_target("ssh://#{user}:#{password}@neptune:2222")
      expect(target.to_s).to eq("ssh://#{user}@neptune:2222")
    end

    describe "with winrm" do
      it "accepts 'winrm://host:port'" do
        target = inventory.get_target('winrm://neptune:55985')
        expect(target.protocol).to eq('winrm')
        expect(target.host).to eq('neptune')
        expect(target.port).to eq(55985)
      end
    end

    describe "with ssh" do
      it "accepts 'ssh://host:port'" do
        target = inventory.get_target('ssh://pluto:2224')
        expect(target.protocol).to eq('ssh')
        expect(target.host).to eq('pluto')
        expect(target.port).to eq(2224)
      end

      it "does not default the ssh port" do
        target = inventory.get_target('ssh://pluto')
        expect(target.protocol).to eq('ssh')
        expect(target.host).to eq('pluto')
        expect(target.port).to be_nil
      end

      it "accepts 'host:port' without a protocol" do
        target = inventory.get_target('pluto:2224')
        expect(target.protocol).to eq('ssh')
        expect(target.host).to eq('pluto')
        expect(target.port).to eq(2224)
      end
    end

    describe "with pcp" do
      it "accepts 'pcp://pluto:666'" do
        target = inventory.get_target('pcp://pluto:666')
        expect(target.protocol).to eq('pcp')
        expect(target.host).to eq('pluto')
        expect(target.port).to eq(666)
      end

      it "accepts 'pcp://pluto' without a port" do
        target = inventory.get_target('pcp://pluto')
        expect(target.protocol).to eq('pcp')
        expect(target.host).to eq('pluto')
        expect(target.port).to be_nil
      end
    end

    it "strips brackets from ipv6 addresses in a uri" do
      target = inventory.get_target('ssh://[::1]:22')
      expect(target.host).to eq('::1')
    end

    it 'can have an empty uri' do
      t1 = inventory.create_target_from_plan('name' => 'name1')
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
