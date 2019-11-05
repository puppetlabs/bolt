# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/transport'
require 'bolt/transport/lxd'
require 'bolt/target'

require_relative 'shared_examples'

describe Bolt::Transport::LXD, lxd: true do
  include BoltSpec::Conn
  include BoltSpec::Transport

  let(:hostname) { conn_info('lxd')[:host] }
  let(:lxd) { Bolt::Transport::LXD.new }
  let(:target) { Bolt::Target.new("lxd://#{hostname}", transport_conf) }

  context 'with lxd' do
    let(:transport) { :lxd }
    let(:os_context) { posix_context }

    it "can test whether the target is available" do
      expect(runner.connected?(target)).to eq(true)
    end

    it "returns false if the target is not available" do
      expect(runner.connected?(Bolt::Target.new('unknownfoo'))).to eq(false)
    end

    include_examples 'transport api'

    context 'file errors' do
      before(:each) do
        allow_any_instance_of(Bolt::Transport::LXD::Connection).to receive(:write_remote_file).and_raise(
          Bolt::Node::FileError.new("no write", "WRITE_ERROR")
        )
        allow_any_instance_of(Bolt::Transport::LXD::Connection).to receive(:make_tempdir).and_raise(
          Bolt::Node::FileError.new("no tmpdir", "TEMDIR_ERROR")
        )
      end

      include_examples 'transport failures'
    end
  end

  context 'with_connection' do
    it "fails with an unknown host" do
      # Test fails differently on Windows due to issues in the lxd-api gem.
      expect {
        lxd.with_connection(Bolt::Target.new('not_a_target')) {}
      }.to raise_error(Bolt::Node::ConnectError, /Could not find a container with name or ID matching \'not_a_target\'/)
    end
  end

  context 'when url is specified' do
    let(:transport_conf) { { 'service-url' => 'tcp://localhost:55555' } }

    it 'uses the url' do
      expect {
        lxd.with_connection(target) {}
      }.to raise_error(Bolt::Node::ConnectError, /Could not find a container with name or ID matching/)
    end
  end

  context 'when there is no host in the target' do
    let(:target) { Bolt::Target.new(nil, "name" => "hostless") }

    it 'errors' do
      expect { lxd.run_command(target, 'whoami') }.to raise_error(/does not have a host/)
    end
  end
end
