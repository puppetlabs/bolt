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

describe Bolt::Transport::SSH do
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

  context 'with ssh', ssh: true do
    let(:transport_config) { no_host_key_check }
    let(:os_context)       { posix_context }
    let(:transport)        { :ssh }

    include BoltSpec::Transport

    include_examples 'transport api'
    include_examples 'with sudo'

    context 'file errors' do
      before(:each) do
        allow_any_instance_of(Bolt::Transport::SSH::Connection).to receive(:copy_file).and_raise(
          Bolt::Node::FileError.new("no write", "WRITE_ERROR")
        )
        allow_any_instance_of(Bolt::Transport::SSH::Connection).to receive(:make_tempdir).and_raise(
          Bolt::Node::FileError.new("no tmpdir", "TEMDIR_ERROR")
        )
      end

      include_examples 'transport failures'
    end
  end

  context "when connecting", ssh: true do
    it "passes proxyjump options" do
      transport_config['proxyjump'] = 'jump.example.com'

      allow(Net::SSH)
        .to receive(:start)
        .with(anything,
              anything,
              hash_including(
                proxy: instance_of(Net::SSH::Proxy::Jump)
              ))
      ssh.with_connection(target) {}
    end

    it "performs secure host key verification by default" do
      allow(Net::SSH)
        .to receive(:start)
        .with(anything,
              anything,
              hash_including(
                verify_host_key: instance_of(Net::SSH::Verifiers::Always)
              ))
      ssh.with_connection(target) {}
    end

    it "downgrades to lenient if host-key-check is false" do
      transport_config.merge!(no_host_key_check)

      allow(Net::SSH)
        .to receive(:start)
        .with(anything,
              anything,
              hash_including(
                verify_host_key: instance_of(Net::SSH::Verifiers::Never)
              ))
      ssh.with_connection(target) {}
    end

    it "defers to SSH config if host-key-check is unset" do
      expect(Net::SSH::Config).to receive(:for).and_return(strict_host_key_checking: false)
      expect(Net::SSH)
        .to receive(:start)
        .with(anything,
              anything,
              hash_including(
                verify_host_key: instance_of(Net::SSH::Verifiers::AcceptNewOrLocalTunnel)
              ))
      ssh.with_connection(target) {}
    end

    it "ignores SSH config if host-key-check is set" do
      transport_config.merge!(no_host_key_check)

      expect(Net::SSH::Config).to receive(:for).and_return(strict_host_key_checking: true)
      allow(Net::SSH)
        .to receive(:start)
        .with(anything,
              anything,
              hash_including(
                verify_host_key: instance_of(Net::SSH::Verifiers::Never)
              ))
      ssh.with_connection(target) {}
    end

    it "rejects the connection if host key verification fails" do
      expect_node_error(Bolt::Node::ConnectError,
                        'HOST_KEY_ERROR',
                        /Host key verification failed/) do
        ssh.with_connection(target) {}
      end
    end

    it "raises ConnectError if authentication fails" do
      transport_config.merge!(no_host_key_check)

      allow(Net::SSH)
        .to receive(:start)
        .and_raise(Net::SSH::AuthenticationFailed,
                   "Authentication failed for foo@bar.com")
      expect_node_error(Bolt::Node::ConnectError,
                        'AUTH_ERROR',
                        /Authentication failed for foo@bar.com/) do
        ssh.with_connection(target) {}
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

    it "adheres to specified connection timeout when connecting to a non-SSH port", ssh: true do
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

    it "uses Net::SSH config when no user is specified" do
      transport_config.merge!(no_user_config)

      expect(Net::SSH::Config)
        .to receive(:for)
        .at_least(:once)
        .with(hostname, any_args)
        .and_return(user: user)

      ssh.with_connection(target) {}
    end

    it "doesn't read system config if load_config is false" do
      transport_config.merge!(no_load_config)

      allow(Etc).to receive(:getlogin).and_return('bolt')
      expect(Net::SSH::Config).not_to receive(:for)
      transport_config['load-config'] = false
      config_user = ssh.with_connection(target, &:user)
      expect(config_user).to be('bolt')
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

    it "executes a command on a host", ssh: true do
      expect(ssh.run_command(target, command).value['stdout']).to eq("/home/#{user}\n")
    end

    it "can upload a file to a host", ssh: true do
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

    it "executes a command on a host", ssh: true do
      expect(ssh.run_command(target, command).value['stdout']).to eq("/home/#{user}\n")
    end
  end

  context "when executing" do
    let(:transport_config) { no_host_key_check }

    it "can test whether the target is available", ssh: true do
      expect(ssh.connected?(target)).to eq(true)
    end

    it "returns false if the target is not available", ssh: true do
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
        expect(ssh).not_to receive(:make_wrapper_stringio)
        result = ssh.run_task(target, task, { 'data' => big_task_input }, run_as: 'root')
        expect(result.value['data'].strip.size).to eq(task_input_size)
      end
    end

    it "runs a task that expects big data in environment variable" do
      expect(ssh).not_to receive(:make_wrapper_stringio)
      with_task_containing('tasks_test', env_task, 'environment') do |task|
        result = ssh.run_task(target, task, { 'data' => big_task_input }, run_as: 'root')
        expect(result.value['_output'].strip.size).to eq(task_input_size)
      end
    end
  end

  context "with non-sudo executable", sudo: true do
    let(:transport_config) do
      {
        'host-key-check'  => false,
        'sudo-executable' => 'fake',
        'run-as'          => user,
        'user'            => bash_user,
        'password'        => bash_password
      }
    end

    it 'uses the correct executable' do
      allow_any_instance_of(Net::SSH::Connection::Channel).to receive(:wait).and_return('')
      expect_any_instance_of(Net::SSH::Connection::Channel).to receive(:exec)
        .with("fake -S -H -u bolt -p \\[sudo\\]\\ Bolt\\ needs\\ to\\ run\\ as\\ another\\ "\
              "user,\\ password:\\  sh -c 'cd && whoami'")

      ssh.run_command(target, 'whoami')
    end
  end

  context "with sudo with task interpreter set", sudo: true, ssh: true do
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
      expect(ssh).not_to receive(:make_wrapper_stringio)
      with_task_containing('tasks_test', stdin_task, 'stdin', '.sh') do |task|
        result = ssh.run_task(target, task, { 'data' => big_task_input }, run_as: 'root')
        expect(result.value['data'].strip.size).to eq(task_input_size)
      end
    end

    it "runs a task that expects big data in environment variable" do
      expect(ssh).not_to receive(:make_wrapper_stringio)
      with_task_containing('tasks_test', env_task, 'environment', '.sh') do |task|
        result = ssh.run_task(target, task, { 'data' => big_task_input }, run_as: 'root')
        expect(result.value['_output'].strip.size).to eq(task_input_size)
      end
    end
  end

  context "with no sudo-password", sudo: true, ssh: true do
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

    it "warns but succeeds when the private-key is missing", ssh: true do
      stub_logger
      expect(mock_logger).to receive(:warn)
      expect(ssh.run_command(target, 'whoami')['exit_code']).to eq(0)
    end
  end

  context "requesting a pty", sudo: true, ssh: true do
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
      expect(ssh).to receive(:make_wrapper_stringio).and_call_original
      with_task_containing('tasks_test', stdin_task, 'stdin') do |task|
        result = ssh.run_task(target, task, { 'data' => big_task_input }, run_as: 'root')
        expect(result.value['data'].strip.size).to eq(task_input_size)
      end
    end

    it "runs a task that expects big data in environment variable" do
      expect(ssh).not_to receive(:make_wrapper_stringio)
      with_task_containing('tasks_test', env_task, 'environment') do |task|
        result = ssh.run_task(target, task, { 'data' => big_task_input }, run_as: 'root')
        expect(result.value['_output'].strip.size).to eq(task_input_size)
      end
    end
  end

  context "when requesting a pty with task interpreter set", sudo: true, ssh: true do
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
      expect(ssh).to receive(:make_wrapper_stringio).and_call_original
      with_task_containing('tasks_test', stdin_task, 'stdin', '.sh') do |task|
        result = ssh.run_task(target, task, { 'data' => big_task_input }, run_as: 'root')
        expect(result.value['data'].strip.size).to eq(task_input_size)
      end
    end

    it "runs a task that expects big data in environment variable" do
      expect(ssh).not_to receive(:make_wrapper_stringio)
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

    it "uploads scripts to the specified directory", ssh: true do
      cmd = 'cd $( dirname $0) && pwd'
      with_tempfile_containing('dir', cmd, '.sh') do |script|
        result = ssh.run_script(target, script.path, nil)
        expect(result.value['stdout']).to eq("/tmp/123456\n")
      end
    end
  end
end
