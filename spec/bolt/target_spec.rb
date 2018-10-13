# frozen_string_literal: true

require 'spec_helper'
require 'bolt/target'

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
end
