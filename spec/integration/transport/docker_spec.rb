# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/transport'
require 'bolt/transport/docker'
require 'bolt/inventory'

require 'shared_examples/transport'

describe Bolt::Transport::Docker, docker: true do
  include BoltSpec::Conn
  include BoltSpec::Transport

  let(:hostname) { conn_info('docker')[:host] }
  let(:docker) { Bolt::Transport::Docker.new }
  let(:inventory) { Bolt::Inventory.empty }
  let(:target) { inventory.get_target(target_data['uri']) }
  let(:target_data) {
    { 'uri' => "docker://#{hostname}",
      'config' => { 'docker' => transport_conf } }
  }

  context 'with docker' do
    let(:transport) { :docker }
    let(:os_context) { posix_context }

    it "can test whether the target is available" do
      expect(runner.connected?(target)).to eq(true)
    end

    it "returns false if the target is not available" do
      expect(runner.connected?(inventory.get_target('unknownfoo'))).to eq(false)
    end

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
        docker.with_connection(inventory.get_target('not_a_target')) {}
      }.to raise_error(Bolt::Node::ConnectError, /Could not find a container with name or ID matching \'not_a_target\'/)
    end
  end

  context 'when url is specified' do
    it 'uses the url' do
      update_target(target, 'service-url' => 'tcp://localhost:55555')
      expect {
        docker.with_connection(target) {}
      }.to raise_error(Bolt::Node::ConnectError, /Could not find a container with name or ID matching/)
    end
  end

  context 'when there is no host in the target' do
    # Directly create an inventory target, since Inventory#get_target doesn't allow
    # for passing config and would set the host as the name passed to it
    let(:target) { Bolt::Target.from_hash({ 'name' => 'hostless' }, inventory) }

    it 'errors' do
      expect { docker.run_command(target, 'whoami') }.to raise_error(/does not have a host/)
    end
  end
end
