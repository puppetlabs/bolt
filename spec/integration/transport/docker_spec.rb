# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/transport'
require 'bolt/transport/docker'
require 'bolt/target'

require 'shared_examples/transport'

shared_examples 'docker transport' do |conn_info_key, container_os_context|
  let(:target) { Bolt::Target.new("docker://#{hostname}", default_transport_conf.merge(transport_conf)) }
  let(:docker) { Bolt::Transport::Docker.new }
  let(:hostname) { conn_info(conn_info_key)[:host] }

  context "with #{conn_info_key}" do
    let(:transport) { :docker }
    let(:os_context) { container_os_context }

    before(:all) do
      # Unfortunately, because we're in a before block we can't use the helpful methods from let e.g. hostname
      # The 'transport api' shared examples expect a directory to exist locally, but because this is docker, which is
      # remote, we need to create the directory ourselves, inside the container.
      #
      # This is Windows only.  Probably because unix mv command creates the
      # missing directories whereas cmd.exe mv command doesn't
      if conn_info_key == 'docker-windows'
        temp_dir = 'C:/mytmp'
        temp_target = Bolt::Target.new("docker://#{conn_info(conn_info_key)[:host]}", {})
        Bolt::Transport::Docker.new.with_connection(temp_target) do |conn|
          # Attempt to remove it and ignore any errors
          conn.execute('cmd.exe', '/c', 'rd', '/s', '/q', Bolt::Util.windows_path(temp_dir), {})
          # Create the directory
          _, stderr, exitcode = conn.execute('cmd.exe', '/c', 'mkdir', Bolt::Util.windows_path(temp_dir), {})
          raise "Unable to create temp directory: #{stderr}" unless exitcode.zero? || stderr =~ /already exists/
        end
      end
    end

    it "can test whether the target is available" do
      expect(runner.connected?(target)).to eq(true)
    end

    it "returns false if the target is not available" do
      expect(runner.connected?(Bolt::Target.new('unknownfoo'))).to eq(false)
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
        docker.with_connection(Bolt::Target.new('not_a_target')) {}
      }.to raise_error(Bolt::Node::ConnectError, /Could not find a container with name or ID matching \'not_a_target\'/)
    end
  end

  context 'when url is specified' do
    let(:transport_conf) { { 'service-url' => 'tcp://localhost:55555' } }

    it 'uses the url' do
      expect {
        docker.with_connection(target) {}
      }.to raise_error(Bolt::Node::ConnectError, /Could not find a container with name or ID matching/)
    end
  end

  context 'when there is no host in the target' do
    let(:target) { Bolt::Target.new(nil, "name" => "hostless") }

    it 'errors' do
      expect { docker.run_command(target, 'whoami') }.to raise_error(/does not have a host/)
    end
  end
end

describe Bolt::Transport::Docker, docker: true do
  # Linux Containers
  include BoltSpec::Conn
  include BoltSpec::Transport

  let(:default_transport_conf) { {} }

  include_examples 'docker transport', 'docker', posix_context
end

describe Bolt::Transport::Docker, docker_wcow: true do
  # Windows Containers
  include BoltSpec::Conn
  include BoltSpec::Transport

  let(:default_transport_conf) {
    {
      'interpreters' => {
        # Unlike a linux based container, commands like echo are not binaries, they require a shell. Because Windows
        # Containers could be using either cmd.exe, powershell.exe, or even, pwsh.exe as the shell we can't assume
        # anything and instead need to be very specific about which interpreter we're going to use
        '.bat' => ['cmd.exe', '/c'],
        '.ps1' => ['powershell.exe', '-NoProfile', '-NonInteractive', '-NoLogo', '-ExecutionPolicy', 'Bypass', '-File']
      }
    }
  }

  context 'using PowerShell' do
    include_examples 'docker transport', 'docker-windows', windows_powershell_container_context
  end

  context 'using cmd.exe' do
    include_examples 'docker transport', 'docker-windows', windows_cmd_container_context
  end
end
