# frozen_string_literal: true

require 'spec_helper'
require 'net/ssh'
require 'bolt_spec/errors'
require 'bolt_spec/files'
require 'bolt_spec/sensitive'
require 'bolt_spec/task'
require 'bolt/transport/ssh'
require 'bolt/config'
require 'bolt/util'

describe Bolt::Transport::SSH do
  include BoltSpec::Errors
  include BoltSpec::Files
  include BoltSpec::Sensitive
  include BoltSpec::Task

  let(:boltdir) { Bolt::Boltdir.new('.') }

  def mk_config(conf)
    conf = Bolt::Util.walk_keys(conf, &:to_s)
    Bolt::Config.new(boltdir, 'ssh' => conf)
  end

  let(:hostname) { ENV['BOLT_SSH_HOST'] || "localhost" }
  let(:user) { ENV['BOLT_SSH_USER'] || "bolt" }
  let(:password) { ENV['BOLT_SSH_PASSWORD'] || "bolt" }
  let(:bash_user) { 'test' }
  let(:bash_password) { 'test' }
  let(:port) { ENV['BOLT_SSH_PORT'] || 20022 }
  let(:key) { ENV['BOLT_SSH_KEY'] || Dir["spec/fixtures/keys/id_rsa"][0] }
  let(:command) { "pwd" }
  let(:config) { mk_config(user: user, password: password) }
  let(:no_host_key_check) { mk_config('host-key-check' => false, user: user, password: password) }
  let(:no_user_config) { mk_config('host-key-check' => false, user: nil, password: password) }
  let(:ssh) { Bolt::Transport::SSH.new }
  let(:echo_script) { <<BASH }
for var in "$@"
do
    echo $var
done
BASH

  def make_target(host_: hostname, port_: port, conf: config)
    Bolt::Target.new("#{host_}:#{port_}").update_conf(conf.transport_conf)
  end

  let(:target) { make_target }

  def result_value(stdout = nil, stderr = nil, exit_code = 0)
    { 'stdout' => stdout || '',
      'stderr' => stderr || '',
      'exit_code' => exit_code }
  end

  context "when connecting", ssh: true do
    it "performs secure host key verification by default" do
      allow(Net::SSH)
        .to receive(:start)
        .with(anything,
              anything,
              hash_including(
                verify_host_key: instance_of(Net::SSH::Verifiers::Secure)
              ))
      ssh.with_connection(target) {}
    end

    it "downgrades to lenient if host-key-check is false" do
      allow(Net::SSH)
        .to receive(:start)
        .with(anything,
              anything,
              hash_including(
                verify_host_key: instance_of(Net::SSH::Verifiers::Null)
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
          '_output' => "Uploaded '#{file.path}' to '#{hostname}:#{remote_path}'"
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

    it "executes a command on a host", ssh: true do
      expect(ssh.run_command(target, command).value).to eq(result_value("/home/#{user}\n"))
    end

    it "captures stderr from a host", ssh: true do
      expect(ssh.run_command(target, "ssh -V").value['stderr']).to match(/OpenSSH/)
    end

    it "can execute a command containing quotes", ssh: true do
      expect(ssh.run_command(target, "echo 'hello \" world'").value).to eq(result_value("hello \" world\n"))
    end

    it "can upload a file to a host", ssh: true do
      contents = "kljhdfg"
      with_tempfile_containing('upload-test', contents) do |file|
        ssh.upload(target, file.path, "/home/#{user}/upload-test")

        expect(
          ssh.run_command(target, "cat /home/#{user}/upload-test")['stdout']
        ).to eq(contents)

        ssh.run_command(target, "rm /home/#{user}/upload-test")
      end
    end

    it "can run a script remotely", ssh: true do
      contents = "#!/bin/sh\necho hellote"
      with_tempfile_containing('script test', contents) do |file|
        expect(
          ssh.run_script(target, file.path, [])['stdout']
        ).to eq("hellote\n")
      end
    end

    it "can run a script remotely with quoted arguments", ssh: true do
      with_tempfile_containing('script-test-ssh-quotes', echo_script) do |file|
        expect(
          ssh.run_script(target,
                         file.path,
                         ['nospaces',
                          'with spaces',
                          "\"double double\"",
                          "'double single'",
                          '\'single single\'',
                          '"single double"',
                          "double \"double\" double",
                          "double 'single' double",
                          'single "double" single',
                          'single \'single\' single'])['stdout']
        ).to eq(<<QUOTED)
nospaces
with spaces
"double double"
'double single'
'single single'
"single double"
double "double" double
double 'single' double
single "double" single
single 'single' single
QUOTED
      end
    end

    it "can run a script with Sensitive arguments", ssh: true do
      contents = "#!/bin/sh\necho $1\necho $2"
      arguments = ['non-sensitive-arg',
                   make_sensitive('$ecret!')]
      with_tempfile_containing('sensitive_test', contents) do |file|
        expect(
          ssh.run_script(target, file.path, arguments)['stdout']
        ).to eq("non-sensitive-arg\n$ecret!\n")
      end
    end

    it "escapes unsafe shellwords in arguments", ssh: true do
      with_tempfile_containing('script-test-ssh-escape', echo_script) do |file|
        expect(
          ssh.run_script(target,
                         file.path,
                         ['echo $HOME; cat /etc/passwd'])['stdout']
        ).to eq(<<SHELLWORDS)
echo $HOME; cat /etc/passwd
SHELLWORDS
      end
    end

    it "can run a task", ssh: true do
      contents = "#!/bin/sh\necho -n ${PT_message_one} ${PT_message_two}"
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_task_containing('tasks_test', contents, 'environment') do |task|
        expect(ssh.run_task(target, task, arguments).message)
          .to eq('Hello from task Goodbye')
      end
    end

    it "doesn't generate a task wrapper when not needed", ssh: true do
      contents = "#!/bin/sh\necho -n ${PT_message_one} ${PT_message_two}"
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      expect(ssh).not_to receive(:make_wrapper_stringio)
      with_task_containing('tasks_test', contents, 'environment') do |task|
        ssh.run_task(target, task, arguments)
      end
    end

    it "can run a task passing input on stdin", ssh: true do
      contents = "#!/bin/sh\ngrep 'message_one'"
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_task_containing('tasks_test_stdin', contents, 'stdin') do |task|
        expect(ssh.run_task(target, task, arguments).value)
          .to eq("message_one" => "Hello from task", "message_two" => "Goodbye")
      end
    end

    it "serializes hashes as json in environment input", ssh: true do
      contents = "#!/bin/sh\nprintenv PT_message"
      arguments = { message: { key: 'val' } }
      with_task_containing('tasks_test_hash', contents, 'environment') do |task|
        expect(ssh.run_task(target, task, arguments).value)
          .to eq('key' => 'val')
      end
    end

    it "can run a task passing input on stdin and environment", ssh: true do
      contents = <<SHELL
#!/bin/sh
echo -n ${PT_message_one} ${PT_message_two}
grep 'message_one'
SHELL
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_task_containing('tasks-test-both', contents, 'both') do |task|
        expect(ssh.run_task(target, task, arguments).message).to eq(<<SHELL)
Hello from task Goodbye{\"message_one\":\
\"Hello from task\",\"message_two\":\"Goodbye\"}
SHELL
      end
    end

    it "can run a task with params containing quotes", ssh: true do
      contents = <<SHELL
#!/bin/sh
echo -n ${PT_message}
SHELL

      arguments = { message: "foo ' bar ' baz" }
      with_task_containing('tasks_test_quotes', contents, 'both') do |task|
        expect(ssh.run_task(target, task, arguments).message).to eq "foo ' bar ' baz"
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

    it "can run a task with Sensitive params via environment", ssh: true do
      contents = <<SHELL
#!/bin/sh
echo ${PT_sensitive_string}
echo ${PT_sensitive_array}
echo -n ${PT_sensitive_hash}
SHELL
      deep_hash = { 'k' => make_sensitive('v') }
      arguments = { 'sensitive_string' => make_sensitive('$ecret!'),
                    'sensitive_array'  => make_sensitive([1, 2, make_sensitive(3)]),
                    'sensitive_hash'   => make_sensitive(deep_hash) }
      with_task_containing('tasks_test_sensitive', contents, 'both') do |task|
        expect(ssh.run_task(target, task, arguments).message).to eq(<<SHELL.strip)
$ecret!
[1,2,3]
{"k":"v"}
SHELL
      end
    end

    it "can run a task with Sensitive params via stdin", ssh: true do
      contents = <<SHELL
#!/bin/sh
cat -
SHELL
      arguments = { 'sensitive_string' => make_sensitive('$ecret!') }
      with_task_containing('tasks_test_sensitive', contents, 'stdin') do |task|
        expect(ssh.run_task(target, task, arguments).value)
          .to eq("sensitive_string" => "$ecret!")
      end
    end

    context "when it can't upload a file" do
      before(:each) do
        allow_any_instance_of(Bolt::Transport::SSH::Connection).to receive(:write_remote_file).and_raise(
          Bolt::Node::FileError.new("no write", "WRITE_ERROR")
        )
      end

      it 'returns an error result for upload', ssh: true do
        contents = "kljhdfg"
        with_tempfile_containing('upload-test', contents) do |file|
          expect {
            ssh.upload(target, file.path, "/home/#{user}/upload-test")
          }.to raise_error(Bolt::Node::FileError, 'no write')
        end
      end

      it 'returns an error result for run_script', ssh: true do
        contents = "#!/bin/sh\necho hellote"
        with_tempfile_containing('script test', contents) do |file|
          expect {
            ssh.run_script(target, file.path, [])
          }.to raise_error(Bolt::Node::FileError, 'no write')
        end
      end

      it 'returns an error result for run_task', ssh: true do
        contents = "#!/bin/sh\necho -n ${PT_message_one} ${PT_message_two}"
        arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
        with_task_containing('tasks_test', contents, 'environment') do |task|
          expect {
            ssh.run_task(target, task, arguments)
          }.to raise_error(Bolt::Node::FileError, 'no write')
        end
      end
    end

    context "when it can't create a tempfile" do
      before(:each) do
        allow_any_instance_of(Bolt::Transport::SSH::Connection).to receive(:make_tempdir).and_raise(
          Bolt::Node::FileError.new("no tmpdir", "TEMDIR_ERROR")
        )
      end

      it 'errors when it tries to run a script', ssh: true do
        contents = "#!/bin/sh\necho hellote"
        with_tempfile_containing('script test', contents) do |file|
          expect {
            ssh.run_script(target, file.path, []).error_hash['msg']
          }.to raise_error(Bolt::Node::FileError, 'no tmpdir')
        end
      end

      it "errors when it tries to run a task", ssh: true do
        contents = "#!/bin/sh\necho -n ${PT_message_one} ${PT_message_two}"
        arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
        with_task_containing('tasks_test', contents, 'environment') do |task|
          expect {
            ssh.run_task(target, task, arguments)
          }.to raise_error(Bolt::Node::FileError, 'no tmpdir')
        end
      end
    end

    context "when implementations are provided", ssh: true do
      let(:contents) { "#!/bin/sh\necho -n ${PT_message_one} ${PT_message_two}" }
      let(:arguments) { { message_one: 'Hello from task', message_two: 'Goodbye' } }

      it "runs a task requires 'shell'" do
        with_task_containing('tasks_test', contents, 'environment') do |task|
          task['metadata']['implementations'] = [{ 'name' => 'tasks_test', 'requirements' => ['shell'] }]
          expect(ssh.run_task(target, task, arguments).message)
            .to eq('Hello from task Goodbye')
        end
      end

      it "runs a task with the implementation's input method" do
        with_task_containing('tasks_test', contents, 'stdin') do |task|
          task['metadata']['implementations'] = [{
            'name' => 'tasks_test', 'requirements' => ['shell'], 'input_method' => 'environment'
          }]
          expect(ssh.run_task(target, task, arguments).message.chomp)
            .to eq('Hello from task Goodbye')
        end
      end

      it "errors when a task only requires an unsupported requirement" do
        with_task_containing('tasks_test', contents, 'environment') do |task|
          task['metadata']['implementations'] = [{ 'name' => 'tasks_test', 'requirements' => ['powershell'] }]
          expect {
            ssh.run_task(target, task, arguments)
          }.to raise_error("No suitable implementation of #{task['name']} for #{target.name}")
        end
      end

      it "errors when a task only requires an unknown requirement" do
        with_task_containing('tasks_test', contents, 'environment') do |task|
          task['metadata']['implementations'] = [{ 'name' => 'tasks_test', 'requirements' => ['foobar'] }]
          expect {
            ssh.run_task(target, task, arguments)
          }.to raise_error("No suitable implementation of #{task['name']} for #{target.name}")
        end
      end
    end
  end

  context 'when tmpdir is specified' do
    let(:tmpdir) { '/tmp/mytempdir' }
    let(:config) { mk_config('host-key-check' => false, tmpdir: tmpdir, user: user, password: password) }

    after(:each) do
      ssh.run_command(target, "rm -rf #{tmpdir}")
    end

    it "errors when tmpdir doesn't exist", ssh: true do
      contents = "#!/bin/sh\n echo $0"
      with_tempfile_containing('script dir', contents) do |file|
        expect {
          ssh.run_script(target, file.path, [])
        }.to raise_error(Bolt::Node::FileError, /Could not make tempdir.*#{Regexp.escape(tmpdir)}/)
      end
    end

    it 'uploads a script to the specified tmpdir', ssh: true do
      ssh.run_command(target, "mkdir #{tmpdir}")
      contents = "#!/bin/sh\n echo $0"
      with_tempfile_containing('script dir', contents) do |file|
        expect(ssh.run_script(target, file.path, [])['stdout']).to match(/#{Regexp.escape(tmpdir)}/)
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
