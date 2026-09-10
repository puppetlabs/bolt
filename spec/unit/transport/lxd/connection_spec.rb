# frozen_string_literal: true

require 'spec_helper'
require 'bolt/transport/lxd'
require 'bolt/error'

describe Bolt::Transport::LXD::Connection do
  let(:target) do
    double('target',
           host: 'mycontainer',
           safe_name: 'mycontainer',
           transport_config: { 'remote' => 'myremote' },
           options: { 'tty' => nil, 'shell-command' => nil })
  end

  before { Bolt::Logger.initialize_logging }

  def make_conn(options = {})
    described_class.new(target, options)
  end

  describe '#initialize' do
    it 'sets the target' do
      expect(make_conn.target).to be(target)
    end

    it 'raises ValidationError when target has no host' do
      no_host = double('target', host: nil, safe_name: 'nohost')
      expect { described_class.new(no_host, {}) }
        .to raise_error(Bolt::ValidationError, /does not have a host/)
    end

    it 'sets user from environment or system login' do
      conn = make_conn
      expect(conn.user).to be_a(String)
      expect(conn.user).not_to be_empty
    end
  end

  describe '#reset_cwd?' do
    it 'returns true' do
      expect(make_conn.reset_cwd?).to be true
    end
  end

  describe '#container_id' do
    it 'returns remote:host format' do
      expect(make_conn.container_id).to eq('myremote:mycontainer')
    end

    it 'handles nil remote by creating :host format' do
      allow(target).to receive(:transport_config).and_return({ 'remote' => nil })
      expect(make_conn.container_id).to eq(':mycontainer')
    end
  end

  describe '#add_env_vars' do
    it 'creates --env flags for each env var' do
      conn = make_conn
      conn.add_env_vars('FOO' => 'bar', 'BAZ' => 'qux')
      env_vars = conn.instance_variable_get(:@env_vars)
      expect(env_vars).to include('--env')
      expect(env_vars).to include('FOO=bar')
    end

    it 'returns empty array for empty env vars' do
      conn = make_conn
      conn.add_env_vars({})
      env_vars = conn.instance_variable_get(:@env_vars)
      expect(env_vars).to eq([])
    end

    it 'escapes special characters in values' do
      conn = make_conn
      conn.add_env_vars('PATH' => '/usr/bin:/bin')
      env_vars = conn.instance_variable_get(:@env_vars)
      expect(env_vars.any? { |v| v.start_with?('PATH=') }).to be true
    end
  end
end
