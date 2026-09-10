# frozen_string_literal: true

require 'spec_helper'
require 'bolt/transport/docker'
require 'bolt/error'

describe Bolt::Transport::Docker::Connection do
  let(:target) do
    double('target',
           host: 'mycontainer',
           safe_name: 'mycontainer',
           options: { 'service-url' => nil, 'tty' => nil, 'shell-command' => nil })
  end

  before { Bolt::Logger.initialize_logging }

  def make_conn
    described_class.new(target)
  end

  describe '#initialize' do
    it 'sets the target' do
      expect(make_conn.target).to be(target)
    end

    it 'raises ValidationError when target has no host' do
      no_host = double('target', host: nil, safe_name: 'nohost')
      expect { described_class.new(no_host) }
        .to raise_error(Bolt::ValidationError, /does not have a host/)
    end

    it 'sets user from environment or system login' do
      conn = make_conn
      expect(conn.user).to be_a(String)
      expect(conn.user).not_to be_empty
    end

    it 'stores docker_host from service-url option' do
      allow(target).to receive(:options).and_return({ 'service-url' => 'tcp://docker.example.com:2376' })
      conn = described_class.new(target)
      expect(conn.instance_variable_get(:@docker_host)).to eq('tcp://docker.example.com:2376')
    end
  end

  describe '#reset_cwd?' do
    it 'returns true' do
      expect(make_conn.reset_cwd?).to be true
    end
  end

  describe '#container_id' do
    it 'returns nil when not yet connected' do
      expect(make_conn.container_id).to be_nil
    end
  end

  describe '#add_env_vars' do
    it 'formats env vars using Bolt::Util' do
      conn = make_conn
      conn.add_env_vars('FOO' => 'bar')
      env_vars = conn.instance_variable_get(:@env_vars)
      expect(env_vars).to include('--env')
      expect(env_vars).to include('FOO=bar')
    end

    it 'handles empty env vars' do
      conn = make_conn
      conn.add_env_vars({})
      env_vars = conn.instance_variable_get(:@env_vars)
      expect(env_vars).to eq([])
    end
  end

  describe '#env_hash (private)' do
    it 'returns empty hash when docker_host is nil' do
      conn = make_conn
      expect(conn.send(:env_hash)).to eq({})
    end

    it 'returns DOCKER_HOST hash when docker_host is set' do
      allow(target).to receive(:options).and_return({ 'service-url' => 'tcp://docker.example.com:2376' })
      conn = described_class.new(target)
      expect(conn.send(:env_hash)).to eq({ 'DOCKER_HOST' => 'tcp://docker.example.com:2376' })
    end
  end

  describe '#extract_json (private)' do
    it 'parses multiple JSON lines' do
      conn = make_conn
      stdout = %({"name":"cont1"}\n{"name":"cont2"}\n)
      result = conn.send(:extract_json, stdout)
      expect(result).to eq([{ 'name' => 'cont1' }, { 'name' => 'cont2' }])
    end

    it 'ignores blank lines' do
      conn = make_conn
      stdout = %({"name":"cont1"}\n\n{"name":"cont2"}\n)
      result = conn.send(:extract_json, stdout)
      expect(result.size).to eq(2)
    end

    it 'returns empty array for empty output' do
      conn = make_conn
      expect(conn.send(:extract_json, '')).to eq([])
    end
  end
end
