# frozen_string_literal: true

require 'spec_helper'
require 'net/ssh'
require 'bolt_spec/conn'
require 'bolt_spec/errors'
require 'bolt_spec/transport'
require 'bolt/transport/ssh'
require 'bolt/config'
require 'bolt/target'
require 'bolt/util'

require_relative 'shared_examples'

describe Bolt::Transport::SSH do
  include BoltSpec::Conn
  include BoltSpec::Errors
  include BoltSpec::Files
  include BoltSpec::Task

  def mk_config(conf)
    conf = Bolt::Util.walk_keys(conf, &:to_s)
    Bolt::Config.new(Bolt::Boltdir.new('.'), 'ssh' => conf)
  end

  let(:hostname) { conn_info('ssh')[:host] }
  let(:user) { conn_info('ssh')[:user] }
  let(:password) { conn_info('ssh')[:password] }
  let(:bash_user) { 'test' }
  let(:bash_password) { 'test' }
  let(:port) { conn_info('ssh')[:port] }
  let(:key) { conn_info('ssh')[:key] }
  let(:command) { "pwd" }
  let(:config) { mk_config(user: user, password: password) }
  let(:no_host_key_check) { mk_config('host-key-check' => false, user: user, password: password) }
  let(:no_user_config) { mk_config('host-key-check' => false, user: nil, password: password) }
  let(:ssh) { Bolt::Transport::SSH.new }

  let(:transport_conf) { {} }
  def make_target(host_: hostname, port_: port, conf: config)
    Bolt::Target.new("#{host_}:#{port_}", transport_conf).update_conf(conf.transport_conf)
  end

  let(:target) { make_target }

  context 'with ssh', ssh: true do
    let(:target) { make_target(conf: no_host_key_check) }
    let(:transport) { :ssh }
    let(:os_context) { posix_context }

    include BoltSpec::Transport

    include_examples 'transport api'

    context 'file errors' do
      before(:each) do
        allow_any_instance_of(Bolt::Transport::SSH::Connection).to receive(:write_remote_file).and_raise(
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
      allow(Net::SSH)
        .to receive(:start)
        .with(anything,
              anything,
              hash_including(
                verify_host_key: instance_of(Net::SSH::Verifiers::Never)
              ))
      ssh.with_connection(make_target(conf: no_host_key_check)) {}
    end

    it "rejects the connection if host key verification fails" do
      expect_node_error(Bolt::Node::ConnectError,
                        'HOST_KEY_ERROR',
                        /Host key verification failed/) do
        ssh.with_connection(target) {}
      end
    end

    it "raises ConnectError if authentication fails" do
      allow(Net::SSH)
        .to receive(:start)
        .and_raise(Net::SSH::AuthenticationFailed,
                   "Authentication failed for foo@bar.com")
      expect_node_error(Bolt::Node::ConnectError,
                        'AUTH_ERROR',
                        /Authentication failed for foo@bar.com/) do
        ssh.with_connection(make_target(conf: no_host_key_check)) {}
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

        timeout = mk_config('connect-timeout' => 2, user: 'bad', password: 'password')

        exec_time = Time.now
        expect {
          ssh.with_connection(make_target(port_: port, conf: timeout)) {}
        }.to raise_error(Bolt::Node::ConnectError)
        expect(Time.now - exec_time).to be > 2
      end
    end

    it "uses Net::SSH config when no user is specified" do
      expect(Net::SSH::Config)
        .to receive(:for)
        .at_least(:once)
        .with(hostname, any_args)
        .and_return(user: user)

      ssh.with_connection(make_target(conf: no_user_config)) {}
    end

    it "doesn't read system config if load_config is false" do
      allow(Etc).to receive(:getlogin).and_return('bolt')
      expect(Net::SSH::Config).not_to receive(:for)

      config_user = ssh.with_connection(make_target(conf: no_user_config), false, &:user)
      expect(config_user).to be('bolt')
    end
  end

  context "when executing with private key" do
    let(:config) { mk_config('host-key-check' => false, 'private-key' => key, user: user, port_: port) }

    it "executes a command on a host", ssh: true do
      expect(ssh.run_command(target, command).value['stdout']).to eq("/home/#{user}\n")
    end

    it "can upload a file to a host", ssh: true do
      target = make_target

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
    let(:config) do
      key_data = File.open(key, 'r', &:read)
      mk_config('host-key-check' => false,
                'private-key' => { 'key-data' => key_data },
                user: user, port_: port)
    end

    it "executes a command on a host", ssh: true do
      expect(ssh.run_command(target, command).value['stdout']).to eq("/home/#{user}\n")
    end
  end

  context "when executing" do
    let(:target) { make_target(conf: no_host_key_check) }

    it "can test whether the target is available", ssh: true do
      expect(ssh.connected?(target)).to eq(true)
    end

    it "returns false if the target is not available", ssh: true do
      expect(ssh.connected?(Bolt::Target.new('unknownfoo'))).to eq(false)
    end

    it "doesn't generate a task wrapper when not needed", ssh: true do
      contents = "#!/bin/sh\necho -n ${PT_message_one} ${PT_message_two}"
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      expect(ssh).not_to receive(:make_wrapper_stringio)
      with_task_containing('tasks_test', contents, 'environment') do |task|
        ssh.run_task(target, task, arguments)
      end
    end
  end

  context "with sudo" do
    let(:config) {
      mk_config('host-key-check' => false, 'sudo-password' => password, 'run-as' => 'root',
                user: user, password: password)
    }

    it "can execute a command", ssh: true do
      expect(ssh.run_command(target, 'whoami')['stdout']).to eq("root\n")
    end

    it "can run a task passing input on stdin", ssh: true do
      contents = "#!/bin/sh\ngrep 'message_one'"
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_task_containing('tasks_test_stdin', contents, 'stdin') do |task|
        expect(ssh.run_task(target, task, arguments).value)
          .to eq("message_one" => "Hello from task", "message_two" => "Goodbye")
      end
    end

    it "can run a task passing input with environment vars", ssh: true do
      contents = "#!/bin/sh\necho -n ${PT_message_one} then ${PT_message_two}"
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_task_containing('tasks_test', contents, 'environment') do |task|
        expect(ssh.run_task(target, task, arguments).message)
          .to eq('Hello from task then Goodbye')
      end
    end

    it "can run a task with params containing variable references", ssh: true do
      contents = <<SHELL
#!/bin/sh
cat
SHELL

      arguments = { message: "$PATH" }
      with_task_containing('tasks_test_var', contents, 'both') do |task|
        expect(ssh.run_task(target, task, arguments)['message']).to eq("$PATH")
      end
    end

    it "can upload a file as root", ssh: true do
      contents = "upload file test as root content"
      dest = '/tmp/root-file-upload-test'
      with_tempfile_containing('tasks test upload as root', contents) do |file|
        expect(ssh.upload(target, file.path, dest).message).to match(/Uploaded/)
        expect(ssh.run_command(target, "cat #{dest}")['stdout']).to eq(contents)
        expect(ssh.run_command(target, "stat -c %U #{dest}")['stdout'].chomp).to eq('root')
        expect(ssh.run_command(target, "stat -c %G #{dest}")['stdout'].chomp).to eq('root')
      end

      ssh.run_command(target, "rm #{dest}", sudoable: true, run_as: 'root')
    end

    context "requesting a pty" do
      let(:config) {
        mk_config('host-key-check' => false, 'sudo-password' => password, 'run-as' => 'root',
                  tty: true, user: user, password: password)
      }

      it "can execute a command when a tty is requested", ssh: true do
        expect(ssh.run_command(target, 'whoami')['stdout'].strip).to eq('root')
      end
    end

    context "as non-root" do
      let(:config) {
        mk_config('host-key-check' => false, 'sudo-password' => bash_password, 'run-as' => user,
                  user: bash_user, password: bash_password)
      }

      it 'runs as that user', ssh: true do
        expect(ssh.run_command(target, 'whoami')['stdout'].chomp).to eq(user)
      end

      it "can override run_as for command via an option", ssh: true do
        expect(ssh.run_command(target, 'whoami', '_run_as' => 'root')['stdout']).to eq("root\n")
      end

      it "can override run_as for script via an option", ssh: true do
        contents = "#!/bin/sh\nwhoami"
        with_tempfile_containing('script test', contents) do |file|
          expect(ssh.run_script(target, file.path, [], '_run_as' => 'root')['stdout']).to eq("root\n")
        end
      end

      it "can override run_as for task via an option", ssh: true do
        contents = "#!/bin/sh\nwhoami"
        with_task_containing('tasks_test', contents, 'environment') do |task|
          expect(ssh.run_task(target, task, {}, '_run_as' => 'root').message).to eq("root\n")
        end
      end

      it "can override run_as for file upload via an option", ssh: true do
        contents = "upload file test as root content"
        dest = '/tmp/root-file-upload-test'
        with_tempfile_containing('tasks test upload as root', contents) do |file|
          expect(ssh.upload(target, file.path, dest, '_run_as' => 'root').message).to match(/Uploaded/)
          expect(ssh.run_command(target, "cat #{dest}", '_run_as' => 'root')['stdout']).to eq(contents)
          expect(ssh.run_command(target, "stat -c %U #{dest}", '_run_as' => 'root')['stdout'].chomp).to eq('root')
          expect(ssh.run_command(target, "stat -c %G #{dest}", '_run_as' => 'root')['stdout'].chomp).to eq('root')
        end

        ssh.run_command(target, "rm #{dest}", sudoable: true, run_as: 'root')
      end
    end

    context "with an incorrect password" do
      let(:config) {
        mk_config('host-key-check' => false, 'sudo-password' => 'nonsense', 'run-as' => 'root',
                  user: user, password: password)
      }

      it "returns a failed result", ssh: true do
        expect {
          ssh.run_command(target, 'whoami')
        }.to raise_error(Bolt::Node::EscalateError,
                         "Sudo password for user #{user} not recognized on #{hostname}:#{port}")
      end
    end

    context "with no password" do
      let(:config) { mk_config('host-key-check' => false, 'run-as' => 'root', user: user, password: password) }

      it "returns a failed result", ssh: true do
        expect {
          ssh.run_command(target, 'whoami')
        }.to raise_error(Bolt::Node::EscalateError,
                         "Sudo password for user #{user} was not provided for #{hostname}:#{port}")
      end
    end

    context "as bash user with no password" do
      let(:config) {
        mk_config('host-key-check' => false, 'run-as' => 'root', user: bash_user, password: bash_password)
      }

      it "returns a failed result when a temporary directory is created", ssh: true do
        contents = "#!/bin/sh\nwhoami"
        with_tempfile_containing('script test', contents) do |file|
          expect {
            ssh.run_script(target, file.path, [])
          }.to raise_error(Bolt::Node::EscalateError,
                           "Sudo password for user #{bash_user} was not provided for #{hostname}:#{port}")
        end
      end
    end
  end

  context "using a custom run-as-command" do
    let(:config) {
      mk_config('host-key-check' => false, 'sudo-password' => password, 'run-as' => 'root',
                user: user, password: password,
                'run-as-command' => ["sudo", "-nSEu"])
    }

    it "can fails to execute with sudo -n", ssh: true do
      expect(ssh.run_command(target, 'whoami')['stderr']).to match("sudo: a password is required")
    end
  end
end
