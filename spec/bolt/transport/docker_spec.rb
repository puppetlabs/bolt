# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt/transport/docker'
require 'bolt/target'

require_relative 'shared_examples'

describe Bolt::Transport::Docker, docker: true do
  include BoltSpec::Conn
  let(:hostname) { conn_info('docker')[:host] }
  let(:docker) { Bolt::Transport::Docker.new }
  let(:transport_conf) { {} }
  let(:target) { Bolt::Target.new(hostname, transport_conf) }

  context 'with docker' do
    let(:runner) { docker }
    let(:os_context) { posix_context }

    include_examples 'transport api'

    context 'file errors' do
      before(:each) do
        allow_any_instance_of(Bolt::Transport::Docker::Connection).to receive(:write_remote_file).and_raise(
          Bolt::Node::FileError.new("no write", "WRITE_ERROR")
        )
        allow_any_instance_of(Bolt::Transport::Docker::Connection).to receive(:make_tempdir).and_raise(
          Bolt::Node::FileError.new("no tmpdir", "TEMDIR_ERROR")
        )
      end

      include_examples 'transport failures'
    end
  end

  context 'with_connection' do
    it "fails with an unknown host" do
      # Test fails differently on Windows due to issues in the docker-api gem.
      expect {
        docker.with_connection(Bolt::Target.new('not_a_target')) {}
      }.to raise_error(Bolt::Node::ConnectError, /Failed to connect to not_a_target: No such container: not_a_target/)
    end
  end

  context 'when url is specified' do
    let(:transport_conf) { { 'service-url' => 'tcp://localhost:55555' } }

    it 'uses the url' do
      expect {
        docker.with_connection(target) {}
      }.to raise_error(Bolt::Node::ConnectError, /Connection refused .* 127.0.0.1:55555/)
    end
  end

  context 'when options are specified' do
    let(:transport_conf) { { 'service-options' => { 'read_timeout' => 0 } } }

    it 'uses the options' do
      expect(Docker::Connection).to receive(:new)
        .with('unix:///var/run/docker.sock', 'read_timeout' => 0).and_call_original
      expect(docker.with_connection(target) {}).to eq(nil)
    end
  end
end
