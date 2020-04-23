# frozen_string_literal: true

require 'spec_helper'
require 'net/ssh'
require 'net/ssh/proxy/jump'
require 'bolt_spec/conn'
require 'bolt_spec/errors'
require 'bolt_spec/logger'
require 'bolt_spec/transport'
require 'bolt/transport/ssh'
require 'bolt/config'
require 'bolt/inventory'
require 'bolt/util'

require 'shared_examples/transport'

describe Bolt::Transport::SSH, ssh: true do
  include BoltSpec::Conn
  include BoltSpec::Errors
  include BoltSpec::Files
  include BoltSpec::Task

  let(:hostname)          { conn_info('ssh')[:host] }
  let(:safe_name)         { hostname.to_s }
  let(:port)              { conn_info('ssh')[:port] }
  let(:host_and_port)     { "#{hostname}:#{port}" }
  let(:user)              { conn_info('ssh')[:user] }
  let(:password)          { conn_info('ssh')[:password] }
  let(:bash_user)         { 'test' }
  let(:bash_password)     { 'test' }
  let(:key)               { conn_info('ssh')[:key] }
  let(:command)           { "pwd" }

  let(:no_host_key_check) { { 'host-key-check' => false, user: user, password: password } }
  let(:no_user_config)    { { 'host-key-check' => false, password: password } }
  let(:no_load_config)    { { 'host-key-check' => false, password: password, 'load-config' => false } }

  let(:ssh)               { Bolt::Transport::SSH.new }
  let(:task_input_size)   { 100000 }
  let(:big_task_input)    { "f" * task_input_size }
  let(:stdin_task)        { "#!/bin/sh\ngrep data" }
  let(:env_task)          { "#!/bin/sh\necho $PT_data" }

  let(:config)            { make_config }
  let(:boltdir)           { Bolt::Boltdir.new('.') }
  let(:plugins)           { Bolt::Plugin.setup(config, nil, nil, Bolt::Analytics::NoopClient.new) }
  let(:inventory)         { Bolt::Inventory.create_version({}, config.transport, config.transports, plugins) }
  let(:target)            { make_target }

  let(:transport_config)  { {} }

  def make_config(conf: transport_config)
    conf = Bolt::Util.walk_keys(conf, &:to_s)
    Bolt::Config.new(boltdir, 'ssh' => conf)
  end
  alias_method :mk_config, :make_config

  def make_target(host_: hostname, port_: port)
    inventory.get_target("#{host_}:#{port_}")
  end

  context 'with ssh' do
    let(:transport_config) { no_host_key_check }
    let(:os_context)       { posix_context }
    let(:transport)        { :ssh }

    include BoltSpec::Transport

    include_examples 'transport api'
    include_examples 'with sudo'
  end

  context "when connecting" do
    it "adheres to specified connection timeout when connecting to a non-SSH port" do
      TCPServer.open(0) do |server|
        port = server.addr[1]

        transport_config.merge!('connect-timeout' => 2, 'user' => 'bad', 'password' => 'password')

        exec_time = Time.now
        expect {
          ssh.with_connection(make_target(port_: port)) {}
        }.to raise_error(Bolt::Node::ConnectError)
        expect(Time.now - exec_time).to be > 2
      end
    end

    it "returns Node::ConnectError if the node name can't be resolved" do
      # even with default timeout, name resolution fails in < 1
      exec_time = Time.now
      expect_node_error(Bolt::Node::ConnectError,
                        'CONNECT_ERROR',
                        /Failed to connect to/) do
        ssh.with_connection(make_target(host_: 'totally-not-there')) {}
      end
      exec_time = Time.now - exec_time
      expect(exec_time).to be < 1
    end

    it "returns Node::ConnectError if the connection is refused" do
      # even with default timeout, connection refused fails in < 1
      exec_time = Time.now
      expect_node_error(Bolt::Node::ConnectError,
                        'CONNECT_ERROR',
                        /Failed to connect to/) do
        ssh.with_connection(make_target(port_: 65535)) {}
      end
      exec_time = Time.now - exec_time
      expect(exec_time).to be < 1
    end

    it "returns Node::ConnectError if the connection times out" do
      allow(Net::SSH)
        .to receive(:start)
        .and_raise(Net::SSH::ConnectionTimeout)
      expect_node_error(Bolt::Node::ConnectError,
                        'CONNECT_ERROR',
                        /Timeout after \d+ seconds connecting to/) do
        ssh.with_connection(target) {}
      end
    end
  end

  context "when executing with private key" do
    let(:transport_config) do
      {
        'host-key-check' => false,
        'private-key'    => key,
        'user'           => user,
        'port'           => port
      }
    end

    it "executes a command on a host" do
      expect(ssh.run_command(target, command).value['stdout']).to eq("/home/#{user}\n")
    end

    it "can upload a file to a host" do
      contents = "kljhdfg"
      remote_path = '/tmp/upload-test'
      with_tempfile_containing('upload-test', contents) do |file|
        expect(
          ssh.upload(target, file.path, remote_path).value
        ).to eq(
          '_output' => "Uploaded '#{file.path}' to '#{target.host}:#{remote_path}'"
        )

        expect(
          ssh.run_command(target, "cat #{remote_path}").value['stdout']
        ).to eq(contents)

        ssh.run_command(target, "rm #{remote_path}")
      end
    end
  end

  context "when executing with private key data" do
    let(:key_data) { File.open(key, 'r', &:read) }
    let(:transport_config) do
      {
        'host-key-check' => false,
        'private-key'    => { 'key-data' => key_data },
        'user'           => user,
        'port'           => port
      }
    end

    it "executes a command on a host" do
      expect(ssh.run_command(target, command).value['stdout']).to eq("/home/#{user}\n")
    end
  end

  context "when executing" do
    let(:transport_config) { no_host_key_check }

    it "can test whether the target is available" do
      expect(ssh.connected?(target)).to eq(true)
    end

    it "returns false if the target is not available" do
      expect(ssh.connected?(inventory.get_target('unknownfoo'))).to eq(false)
    end
  end

  # Local transport doesn't have concept of 'user'
  # so this test only applies to ssh
  context "with sudo as non-root", sudo: true do
    let(:transport_config) do
      {
        'host-key-check' => false,
        'run-as'         => user,
        'user'           => bash_user,
        'password'       => bash_password
      }
    end

    it 'runs as that user' do
      expect(ssh.run_command(target, 'whoami')['stdout'].chomp).to eq(user)
    end

    it "can override run_as for command via an option" do
      expect(ssh.run_command(target, 'whoami', run_as: 'root')['stdout']).to eq("root\n")
    end

    it "can override run_as for script via an option" do
      contents = "#!/bin/sh\nwhoami"
      with_tempfile_containing('script test', contents) do |file|
        expect(ssh.run_script(target, file.path, [], run_as: 'root')['stdout']).to eq("root\n")
      end
    end

    it "can override run_as for task via an option" do
      contents = "#!/bin/sh\nwhoami"
      with_task_containing('tasks_test', contents, 'environment') do |task|
        expect(ssh.run_task(target, task, {}, run_as: 'root').message).to eq("root\n")
      end
    end

    it "can override run_as for file upload via an option" do
      contents = "upload file test as root content"
      dest = '/tmp/root-file-upload-test'
      with_tempfile_containing('tasks test upload as root', contents) do |file|
        expect(ssh.upload(target, file.path, dest, run_as:  'root').message).to match(/Uploaded/)
        expect(ssh.run_command(target, "cat #{dest}", run_as: 'root')['stdout']).to eq(contents)
        expect(ssh.run_command(target, "stat -c %U #{dest}", run_as:  'root')['stdout'].chomp).to eq('root')
        expect(ssh.run_command(target, "stat -c %G #{dest}", run_as:  'root')['stdout'].chomp).to eq('root')
      end

      ssh.run_command(target, "rm #{dest}", sudoable: true, run_as: 'root')
    end

    it "runs from the run-as user's home directory" do
      stdout = ssh.run_command(target, 'pwd; echo $HOME', run_as: 'root')['stdout']
      pwd, homedir = stdout.lines.map(&:chomp)
      expect(pwd).to match(/root/)
      expect(homedir).to match(/root/)
    end

    it "runs a task that expects big data on stdin" do
      with_task_containing('tasks_test', stdin_task, 'stdin') do |task|
        result = ssh.run_task(target, task, { 'data' => big_task_input }, run_as: 'root')
        expect(result.value['data'].strip.size).to eq(task_input_size)
      end
    end

    it "runs a task that expects big data in environment variable" do
      with_task_containing('tasks_test', env_task, 'environment') do |task|
        result = ssh.run_task(target, task, { 'data' => big_task_input }, run_as: 'root')
        expect(result.value['_output'].strip.size).to eq(task_input_size)
      end
    end
  end

  context "with sudo with task interpreter set", sudo: true do
    let(:transport_config) do
      {
        'host-key-check' => false,
        'run-as'         => 'root',
        'user'           => user,
        'password'       => password,
        'interpreters'   => { 'sh' => '/bin/sh' }
      }
    end

    it "runs a task that expects big data on stdin" do
      with_task_containing('tasks_test', stdin_task, 'stdin', '.sh') do |task|
        result = ssh.run_task(target, task, { 'data' => big_task_input }, run_as: 'root')
        expect(result.value['data'].strip.size).to eq(task_input_size)
      end
    end

    it "runs a task that expects big data in environment variable" do
      with_task_containing('tasks_test', env_task, 'environment', '.sh') do |task|
        result = ssh.run_task(target, task, { 'data' => big_task_input }, run_as: 'root')
        expect(result.value['_output'].strip.size).to eq(task_input_size)
      end
    end
  end

  context "with no sudo-password", sudo: true do
    let(:transport_config) do
      {
        'host-key-check' => false,
        'password'       => password,
        'run-as'         => 'root',
        'user'           => user
      }
    end

    it "uses password as sudo-password" do
      expect(ssh.run_command(target, 'whoami')['stdout'].strip).to eq('root')
    end
  end

  context "with a bad private-key option" do
    include BoltSpec::Logger

    let(:transport_config) do
      {
        'host-key-check' => false,
        'private-key'    => '/bad/path/to/key',
        'user'           => user,
        'password'       => password
      }
    end

    it "warns but succeeds when the private-key is missing" do
      stub_logger
      expect(mock_logger).to receive(:warn)
      expect(ssh.run_command(target, 'whoami')['exit_code']).to eq(0)
    end
  end

  context "requesting a pty", sudo: true do
    let(:transport_config) do
      {
        'host-key-check' => false,
        'run-as'         => 'root',
        'tty'            => true,
        'user'           => user,
        'password'       => password
      }
    end

    it "can execute a command when a tty is requested" do
      expect(ssh.run_command(target, 'whoami')['stdout'].strip).to eq('root')
    end

    it "runs a task that expects big data on stdin" do
      with_task_containing('tasks_test', stdin_task, 'stdin') do |task|
        result = ssh.run_task(target, task, { 'data' => big_task_input }, run_as: 'root')
        expect(result.value['data'].strip.size).to eq(task_input_size)
      end
    end

    it "runs a task that expects big data in environment variable" do
      with_task_containing('tasks_test', env_task, 'environment') do |task|
        result = ssh.run_task(target, task, { 'data' => big_task_input }, run_as: 'root')
        expect(result.value['_output'].strip.size).to eq(task_input_size)
      end
    end
  end

  context "when requesting a pty with task interpreter set", sudo: true do
    let(:transport_config) do
      {
        'host-key-check' => false,
        'run-as'         => 'root',
        'tty'            => true,
        'user'           => user,
        'password'       => password,
        'interpreters'   => { 'sh' => '/bin/sh' }
      }
    end

    it "runs a task that expects big data on stdin" do
      with_task_containing('tasks_test', stdin_task, 'stdin', '.sh') do |task|
        result = ssh.run_task(target, task, { 'data' => big_task_input }, run_as: 'root')
        expect(result.value['data'].strip.size).to eq(task_input_size)
      end
    end

    it "runs a task that expects big data in environment variable" do
      with_task_containing('tasks_test', env_task, 'environment', '.sh') do |task|
        result = ssh.run_task(target, task, { 'data' => big_task_input }, run_as: 'root')
        expect(result.value['_output'].strip.size).to eq(task_input_size)
      end
    end
  end

  context 'when there is no host in the target' do
    let(:target) { Bolt::Inventory::Target.new({ 'name' => 'hostless' }, inventory) }

    it 'errors' do
      expect { ssh.run_command(target, 'whoami') }.to raise_error(/does not have a host/)
    end
  end

  context "with specific tempdir using script-dir option" do
    let(:script_dir) { "123456" }
    let(:transport_config) do
      {
        'host-key-check' => false,
        'run-as'         => 'root',
        'user'           => user,
        'password'       => password,
        'script-dir'     => script_dir,
        'interpreters'   => { 'sh' => '/bin/sh' }
      }
    end

    it "uploads scripts to the specified directory" do
      cmd = 'cd $( dirname $0) && pwd'
      with_tempfile_containing('dir', cmd, '.sh') do |script|
        result = ssh.run_script(target, script.path, nil)
        expect(result.value['stdout']).to eq("/tmp/123456\n")
      end
    end
  end
end
