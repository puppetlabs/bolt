require 'spec_helper'
require 'bolt_spec/errors'
require 'bolt_spec/files'
require 'bolt/node'
require 'bolt/node/ssh'
require 'bolt/config'

describe Bolt::SSH do
  include BoltSpec::Errors
  include BoltSpec::Files

  def mk_config(conf)
    Bolt::Config.new(transports: { ssh: conf })
  end

  let(:hostname) { ENV['BOLT_SSH_HOST'] || "localhost" }
  let(:user) { ENV['BOLT_SSH_USER'] || "vagrant" }
  let(:password) { ENV['BOLT_SSH_PASSWORD'] || "vagrant" }
  let(:port) { ENV['BOLT_SSH_PORT'] || 2224 }
  let(:key) { ENV['BOLT_SSH_KEY'] || Dir[".vagrant/**/private_key"] }
  let(:command) { "pwd" }
  let(:config) { mk_config(user: user, password: password) }
  let(:no_host_key_check) { mk_config(host_key_check: false, user: user, password: password) }
  let(:ssh) { Bolt::SSH.new(target) }
  let(:echo_script) { <<BASH }
for var in "$@"
do
    echo $var
done
BASH

  def target(h: hostname, p: port, conf: config)
    Bolt::Target.from_uri("#{h}:#{p}").update_conf(conf.transport_conf)
  end

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
      ssh.connect
    end

    it "downgrades to lenient if host_key_check is false" do
      ssh = Bolt::SSH.new(target(conf: no_host_key_check))

      allow(Net::SSH)
        .to receive(:start)
        .with(anything,
              anything,
              hash_including(
                verify_host_key: instance_of(Net::SSH::Verifiers::Lenient)
              ))
      ssh.connect
    end

    it "rejects the connection if host key verification fails" do
      expect_node_error(Bolt::Node::ConnectError,
                        'HOST_KEY_ERROR',
                        /Host key verification failed/) do
        ssh.connect
      end
    end

    it "raises ConnectError if authentication fails" do
      ssh = Bolt::SSH.new(target(conf: no_host_key_check))

      allow(Net::SSH)
        .to receive(:start)
        .and_raise(Net::SSH::AuthenticationFailed,
                   "Authentication failed for foo@bar.com")
      expect_node_error(Bolt::Node::ConnectError,
                        'AUTH_ERROR',
                        /Authentication failed for foo@bar.com/) do
        ssh.connect
      end
    end

    it "returns Node::ConnectError if the node name can't be resolved" do
      # even with default timeout, name resolution fails in < 1
      ssh = Bolt::SSH.new(target(h: 'totally-not-there'))
      exec_time = Time.now
      expect_node_error(Bolt::Node::ConnectError,
                        'CONNECT_ERROR',
                        /Failed to connect to/) do
        ssh.connect
      end
      exec_time = Time.now - exec_time
      expect(exec_time).to be < 1
    end

    it "returns Node::ConnectError if the connection is refused" do
      # even with default timeout, connection refused fails in < 1
      ssh = Bolt::SSH.new(target(h: hostname, p: 65535))
      exec_time = Time.now
      expect_node_error(Bolt::Node::ConnectError,
                        'CONNECT_ERROR',
                        /Failed to connect to/) do
        ssh.connect
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
        ssh.connect
      end
    end

    it "adheres to specified connection timeout when connecting to a non-SSH port", ssh: true do
      TCPServer.open(0) do |server|
        port = server.addr[1]

        timeout = mk_config(connect_timeout: 2, user: 'bad', password: 'password')
        ssh = Bolt::SSH.new(target(h: hostname, p: port, conf: timeout))

        exec_time = Time.now
        expect {
          ssh.connect
        }.to raise_error(Bolt::Node::ConnectError)
        expect(Time.now - exec_time).to be > 2
      end
    end
  end

  context "when executing with private key" do
    let(:config) { mk_config(host_key_check: false, key: key, user: user) }

    before(:each) { ssh.connect }
    after(:each) { ssh.disconnect }

    it "executes a command on a host", ssh: true do
      expect(ssh.execute(command).stdout.string).to eq("/home/#{user}\n")
    end

    it "can upload a file to a host", ssh: true do
      contents = "kljhdfg"
      remote_path = '/tmp/upload-test'
      with_tempfile_containing('upload-test', contents) do |file|
        expect(
          ssh.upload(file.path, remote_path).value
        ).to eq(
          '_output' => "Uploaded '#{file.path}' to '#{hostname}:#{remote_path}'"
        )

        expect(
          ssh.execute("cat #{remote_path}").stdout.string
        ).to eq(contents)

        ssh.execute("rm #{remote_path}")
      end
    end
  end

  context "when executing" do
    let(:ssh) { Bolt::SSH.new(target(conf: no_host_key_check)) }

    before(:each) { ssh.connect }
    after(:each) { ssh.disconnect }

    it "executes a command on a host", ssh: true do
      expect(ssh.run_command(command).value).to eq(result_value("/home/#{user}\n"))
    end

    it "captures stderr from a host", ssh: true do
      expect(ssh.run_command("ssh -V").value['stderr']).to match(/OpenSSH/)
    end

    it "can upload a file to a host", ssh: true do
      contents = "kljhdfg"
      with_tempfile_containing('upload-test', contents) do |file|
        ssh.upload(file.path, "/home/#{user}/upload-test")

        expect(
          ssh.run_command("cat /home/#{user}/upload-test")['stdout']
        ).to eq(contents)

        ssh.execute("rm /home/#{user}/upload-test")
      end
    end

    it "can run a script remotely", ssh: true do
      contents = "#!/bin/sh\necho hellote"
      with_tempfile_containing('script test', contents) do |file|
        expect(
          ssh.run_script(file.path, [])['stdout']
        ).to eq("hellote\n")
      end
    end

    it "can run a script remotely with quoted arguments", ssh: true do
      with_tempfile_containing('script-test-ssh-quotes', echo_script) do |file|
        expect(
          ssh.run_script(
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
             'single \'single\' single']
          )['stdout']
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

    it "escapes unsafe shellwords in arguments", ssh: true do
      with_tempfile_containing('script-test-ssh-escape', echo_script) do |file|
        expect(
          ssh.run_script(
            file.path,
            ['echo $HOME; cat /etc/passwd']
          )['stdout']
        ).to eq(<<SHELLWORDS)
echo $HOME; cat /etc/passwd
SHELLWORDS
      end
    end

    it "can run a task", ssh: true do
      contents = "#!/bin/sh\necho -n ${PT_message_one} ${PT_message_two}"
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_tempfile_containing('tasks test', contents) do |file|
        expect(ssh.run_task(file.path, 'environment', arguments).message)
          .to eq('Hello from task Goodbye')
      end
    end

    it "doesn't generate a task wrapper when not needed", ssh: true do
      contents = "#!/bin/sh\necho -n ${PT_message_one} ${PT_message_two}"
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_tempfile_containing('tasks test', contents) do |file|
        expect(ssh).not_to receive(:make_wrapper_stringio)
        ssh.run_task(file.path, 'environment', arguments)
      end
    end

    it "can run a task passing input on stdin", ssh: true do
      contents = "#!/bin/sh\ngrep 'message_one'"
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_tempfile_containing('tasks test stdin', contents) do |file|
        expect(ssh.run_task(file.path, 'stdin', arguments).value)
          .to eq("message_one" => "Hello from task", "message_two" => "Goodbye")
      end
    end

    it "can run a task passing input on stdin and environment", ssh: true do
      contents = <<SHELL
#!/bin/sh
echo -n ${PT_message_one} ${PT_message_two}
grep 'message_one'
SHELL
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_tempfile_containing('tasks-test-both', contents) do |file|
        expect(ssh.run_task(file.path, 'both', arguments).message).to eq(<<SHELL)
Hello from task Goodbye{\"message_one\":\
\"Hello from task\",\"message_two\":\"Goodbye\"}
SHELL
      end
    end

    context "when it can't upload a file" do
      before(:each) do
        expect(ssh).to receive(:write_remote_file).and_raise(
          Bolt::Node::FileError.new("no write", "WRITE_ERROR")
        )
      end

      it 'returns an error result for upload', ssh: true do
        contents = "kljhdfg"
        with_tempfile_containing('upload-test', contents) do |file|
          expect {
            ssh.upload(file.path, "/home/#{user}/upload-test")
          }.to raise_error(Bolt::Node::FileError, 'no write')
        end
      end

      it 'returns an error result for run_command', ssh: true do
        contents = "#!/bin/sh\necho hellote"
        with_tempfile_containing('script test', contents) do |file|
          expect {
            ssh.run_script(file.path, [])
          }.to raise_error(Bolt::Node::FileError, 'no write')
        end
      end

      it 'returns an error result for run_task', ssh: true do
        contents = "#!/bin/sh\necho -n ${PT_message_one} ${PT_message_two}"
        arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
        with_tempfile_containing('tasks test', contents) do |file|
          expect {
            ssh.run_task(file.path, 'environment', arguments)
          }.to raise_error(Bolt::Node::FileError, 'no write')
        end
      end
    end

    context "when it can't create a tempfile" do
      before(:each) do
        expect(ssh).to receive(:make_tempdir).and_raise(
          Bolt::Node::FileError.new("no tmpdir", "TEMDIR_ERROR")
        )
      end

      it 'errors when it tries to run a script', ssh: true do
        contents = "#!/bin/sh\necho hellote"
        with_tempfile_containing('script test', contents) do |file|
          expect {
            ssh.run_script(file.path, []).error_hash['msg']
          }.to raise_error(Bolt::Node::FileError, 'no tmpdir')
        end
      end

      it "can run a task", ssh: true do
        contents = "#!/bin/sh\necho -n ${PT_message_one} ${PT_message_two}"
        arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
        with_tempfile_containing('tasks test', contents) do |file|
          expect {
            ssh.run_task(file.path, 'environment', arguments)
          }.to raise_error(Bolt::Node::FileError, 'no tmpdir')
        end
      end
    end
  end

  context 'When tmpdir is specified' do
    let(:tmpdir) { '/tmp/mytempdir' }
    let(:config) { mk_config(host_key_check: false, tmpdir: tmpdir, user: user, password: password) }

    before(:each) { ssh.connect }
    after(:each) do
      begin
        ssh.run_command("rm -rf #{tmpdir}")
      ensure
        ssh.disconnect
      end
    end

    it "errors when tmpdir doesn't exist", ssh: true do
      contents = "#!/bin/sh\n echo $0"
      with_tempfile_containing('script dir', contents) do |file|
        expect {
          ssh.run_script(file.path, [])
        }.to raise_error(Bolt::Node::FileError, /Could not make tempdir.*#{Regexp.escape(tmpdir)}/)
      end
    end

    it 'uploads a script to the specified tmpdir', ssh: true do
      ssh.run_command("mkdir #{tmpdir}")
      contents = "#!/bin/sh\n echo $0"
      with_tempfile_containing('script dir', contents) do |file|
        expect(ssh.run_script(file.path, [])['stdout']).to match(/#{Regexp.escape(tmpdir)}/)
      end
    end
  end

  context "with sudo" do
    let(:config) {
      mk_config(host_key_check: false, sudo_password: password, run_as: 'root', user: user, password: password)
    }

    before(:each) { ssh.connect }
    after(:each) { ssh.disconnect }

    it "can execute a command", ssh: true do
      expect(ssh.run_command('whoami')['stdout']).to eq("root\n")
    end

    it "can run a task passing input on stdin", ssh: true do
      contents = "#!/bin/sh\ngrep 'message_one'"
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_tempfile_containing('tasks test stdin', contents) do |file|
        expect(ssh.run_task(file.path, 'stdin', arguments).value)
          .to eq("message_one" => "Hello from task", "message_two" => "Goodbye")
      end
    end

    it "can upload a file as root", ssh: true do
      contents = "upload file test as root content"
      dest = '/tmp/root-file-upload-test'
      with_tempfile_containing('tasks test upload as root', contents) do |file|
        expect(ssh.upload(file.path, dest).message).to match(/Uploaded/)
        expect(ssh.run_command("cat #{dest}")['stdout']).to eq(contents)
        expect(ssh.run_command("stat -c %U #{dest}")['stdout'].chomp).to eq('root')
      end

      ssh.execute("rm #{dest}", sudoable: true, run_as: 'root')
    end

    context "requesting a pty" do
      let(:config) {
        mk_config(host_key_check: false, sudo_password: password, run_as: 'root',
                  tty: true, user: user, password: password)
      }

      it "can execute a command when a tty is requested", ssh: true do
        expect(ssh.run_command('whoami')['stdout']).to eq("\r\nroot\r\n")
      end
    end

    context "as non-root" do
      let(:config) {
        mk_config(host_key_check: false, sudo_password: password, run_as: user, user: user, password: password)
      }

      it "can override run_as for command via an option", ssh: true do
        expect(ssh.run_command('whoami', '_run_as' => 'root')['stdout']).to eq("root\n")
      end

      it "can override run_as for script via an option", ssh: true do
        contents = "#!/bin/sh\nwhoami"
        with_tempfile_containing('script test', contents) do |file|
          expect(ssh.run_script(file.path, [], '_run_as' => 'root')['stdout']).to eq("root\n")
        end
      end

      it "can override run_as for task via an option", ssh: true do
        contents = "#!/bin/sh\nwhoami"
        with_tempfile_containing('tasks test', contents) do |file|
          expect(ssh.run_task(file.path, 'environment', {}, '_run_as' => 'root').message).to eq("root\n")
        end
      end
    end

    context "with an incorrect password" do
      let(:config) {
        mk_config(host_key_check: false, sudo_password: 'nonsense', run_as: 'root',
                  user: user, password: password)
      }

      it "returns a failed result", ssh: true do
        expect {
          ssh.run_command('whoami')
             .to raise_error(Bolt::Node::EscalateError,
                             "Sudo password for user #{user} not recognized on #{hostname}:#{port}")
        }
      end
    end

    context "with no password" do
      let(:config) { mk_config(host_key_check: false, run_as: 'root', user: user, password: password) }

      it "returns a failed result", ssh: true do
        expect {
          ssh.run_command('whoami')
             .to raise_error(Bolt::Node::EscalateError,
                             "Sudo password for user #{user} was not provided for #{hostname}:#{port}")
        }
      end
    end
  end
end
