# frozen_string_literal: true

require 'spec_helper'
require 'bolt/transport/docker'
require 'bolt/transport/podman'
require 'bolt/error'

describe Bolt::Transport::Podman::Connection do
  let(:target) do
    double('target',
           host: 'mycontainer',
           safe_name: 'mycontainer',
           options: { 'tty' => nil, 'shell-command' => nil })
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
      expect(make_conn.user).to be_a(String)
    end
  end

  describe '#reset_cwd?' do
    it 'returns true' do
      expect(make_conn.reset_cwd?).to be true
    end
  end

  describe '#extract_json (private)' do
    # Use String.new to create mutable strings since strip! requires unfrozen strings
    it 'returns nil for empty output' do
      conn = make_conn
      expect(conn.send(:extract_json, String.new(''))).to be_nil
    end

    it 'parses single-line JSON' do
      conn = make_conn
      result = conn.send(:extract_json, String.new('{"Id":"abc123"}'))
      expect(result).to eq('Id' => 'abc123')
    end

    it 'parses multi-line pretty JSON' do
      conn = make_conn
      json = String.new("{\n  \"Id\": \"abc123\",\n  \"Name\": \"mycontainer\"\n}")
      result = conn.send(:extract_json, json)
      expect(result).to eq('Id' => 'abc123', 'Name' => 'mycontainer')
    end

    it 'returns nil when output has no closing bracket' do
      conn = make_conn
      result = conn.send(:extract_json, String.new('plain text no json'))
      expect(result).to be_nil
    end
  end
end
