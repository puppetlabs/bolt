require 'spec_helper'
require 'bolt_spec/errors'
require 'bolt_spec/files'
require 'bolt/node'
require 'bolt/node/ssh'
require 'bolt/config'

describe Bolt::SSH do
  include BoltSpec::Errors
  include BoltSpec::Files

  let(:hostname) { ENV['BOLT_SSH_HOST'] || "localhost" }
  let(:user) { ENV['BOLT_SSH_USER'] || "vagrant" }
  let(:password) { ENV['BOLT_SSH_PASSWORD'] || "vagrant" }
  let(:port) { ENV['BOLT_SSH_PORT'] || 2224 }
  let(:key) { ENV['BOLT_SSH_KEY'] || Dir[".vagrant/**/private_key"] }
  let(:command) { "pwd" }
  let(:ssh) { Bolt::SSH.new(hostname, port, user, password) }
  let(:insecure) { { config: Bolt::Config.new(transports: { ssh: { insecure: true } }) } }
  let(:echo_script) { <<BASH }
for var in "$@"
do
    echo $var
done
BASH

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

    it "downgrades to lenient if insecure is true" do
      ssh = Bolt::SSH.new(hostname, port, user, password, **insecure)

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
      ssh = Bolt::SSH.new(hostname, port, user, password, **insecure)

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
      ssh = Bolt::SSH.new('totally-not-there', port)
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
      ssh = Bolt::SSH.new(hostname, 65535, user, password)
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
                        /Failed to connect to/) do
        ssh.connect
      end
    end

    it "takes < 2 seconds to fail by default when connecting to a non-SSH port", ssh: true do
      TCPServer.open(0) do |server|
        server.addr[1]

        # CLI failures present on a dead port like:
        # Failed to connect to ssh://localhost:2222:
        #   connection closed by remote host
        #
        # Ran on 1 node in 438.96 seconds
        ssh = Bolt::SSH.new(hostname, port, 'bad', 'password')

        expect {
          Timeout.timeout(2) { ssh.connect }
        }.to raise_error(Bolt::Node::ConnectError)
      end
    end

    it "adheres to specified connection timeout when connecting to a non-SSH port", ssh: true do
      TCPServer.open(0) do |server|
        port = server.addr[1]

        timeout = { config: Bolt::Config.new(transports: { ssh: { timeout: 2 } }) }
        ssh = Bolt::SSH.new(hostname, port, 'bad', 'password', **timeout)

        exec_time = Time.now
        expect {
          ssh.connect
        }.to raise_error(Bolt::Node::ConnectError)
        expect(Time.now - exec_time).to be > 2
      end
    end
  end

  context "when executing with private key" do
    let(:config) { Bolt::Config.new(transports: { ssh: { insecure: true, key: key } }) }
    let(:ssh) { Bolt::SSH.new(hostname, port, user, nil, uri: 'foo', config: config) }

    before(:each) { ssh.connect }
    after(:each) { ssh.disconnect }

    it "executes a command on a host", ssh: true do
      expect(ssh.execute(command).stdout.string).to eq("/home/#{user}\n")
    end

    it "can upload a file to a host", ssh: true do
      contents = "kljhdfg"
      with_tempfile_containing('upload-test', contents) do |file|
        ssh.upload(file.path, "/tmp/upload-test")

        expect(
          ssh.execute("cat /tmp/upload-test").stdout.string
        ).to eq(contents)

        ssh.execute("rm /tmp/upload-test")
      end
    end
  end

  context "when executing" do
    let(:ssh) { Bolt::SSH.new(hostname, port, user, password, **insecure) }

    before(:each) { ssh.connect }
    after(:each) { ssh.disconnect }

    it "executes a command on a host", ssh: true do
      expect(ssh._run_command(command).value).to eq(result_value("/home/#{user}\n"))
    end

    it "captures stderr from a host", ssh: true do
      expect(ssh._run_command("ssh -V").value['stderr']).to match(/OpenSSH/)
    end

    it "can upload a file to a host", ssh: true do
      contents = "kljhdfg"
      with_tempfile_containing('upload-test', contents) do |file|
        ssh.upload(file.path, "/home/#{user}/upload-test")

        expect(
          ssh._run_command("cat /home/#{user}/upload-test").stdout
        ).to eq(contents)

        ssh.execute("rm /home/#{user}/upload-test")
      end
    end

    it "can run a script remotely", ssh: true do
      contents = "#!/bin/sh\necho hellote"
      with_tempfile_containing('script test', contents) do |file|
        expect(
          ssh._run_script(file.path, []).stdout
        ).to eq("hellote\n")
      end
    end

    it "can run a script remotely with quoted arguments", ssh: true do
      with_tempfile_containing('script-test-ssh-quotes', echo_script) do |file|
        expect(
          ssh._run_script(
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
          ).stdout
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
          ssh._run_script(
            file.path,
            ['echo $HOME; cat /etc/passwd']
          ).stdout
        ).to eq(<<SHELLWORDS)
echo $HOME; cat /etc/passwd
SHELLWORDS
      end
    end

    it "can run a task", ssh: true do
      contents = "#!/bin/sh\necho -n ${PT_message_one} ${PT_message_two}"
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_tempfile_containing('tasks test', contents) do |file|
        expect(ssh._run_task(file.path, 'environment', arguments).message)
          .to eq('Hello from task Goodbye')
      end
    end

    it "can run a task passing input on stdin", ssh: true do
      contents = "#!/bin/sh\ngrep 'message_one'"
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_tempfile_containing('tasks test stdin', contents) do |file|
        expect(ssh._run_task(file.path, 'stdin', arguments).value)
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
        expect(ssh._run_task(file.path, 'both', arguments).message).to eq(<<SHELL)
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

      it 'returns an error result for _upload', ssh: true do
        contents = "kljhdfg"
        with_tempfile_containing('upload-test', contents) do |file|
          expect(ssh.upload(file.path, "/home/#{user}/upload-test").error['msg']).to eq('no write')
        end
      end

      it 'returns an error result for _run_command', ssh: true do
        contents = "#!/bin/sh\necho hellote"
        with_tempfile_containing('script test', contents) do |file|
          expect(
            ssh._run_script(file.path, []).error['msg']
          ).to eq("no write")
        end
      end

      it 'returns an error result for _run_task', ssh: true do
        contents = "#!/bin/sh\necho -n ${PT_message_one} ${PT_message_two}"
        arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
        with_tempfile_containing('tasks test', contents) do |file|
          expect(ssh._run_task(file.path, 'environment', arguments).error['msg']).to eq("no write")
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
          expect(
            ssh._run_script(file.path, []).error['msg']
          ).to eq("no tmpdir")
        end
      end

      it "can run a task", ssh: true do
        contents = "#!/bin/sh\necho -n ${PT_message_one} ${PT_message_two}"
        arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
        with_tempfile_containing('tasks test', contents) do |file|
          expect(ssh._run_task(file.path, 'environment', arguments).error['msg']).to eq("no tmpdir")
        end
      end
    end
  end

  context "with sudo" do
    let(:config) do
      Bolt::Config.new(transports: { ssh: {
                         insecure: true,
                         sudo: true,
                         sudo_password: password,
                         run_as: 'root'
                       } })
    end

    let(:ssh) { Bolt::SSH.new(hostname, port, user, password, config: config) }

    before(:each) { ssh.connect }
    after(:each) { ssh.disconnect }

    it "can execute a command", ssh: true do
      expect(ssh._run_command('whoami').stdout).to eq("root\n")
    end

    it "can run a task passing input on stdin", ssh: true do
      contents = "#!/bin/sh\ngrep 'message_one'"
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_tempfile_containing('tasks test stdin', contents) do |file|
        expect(ssh._run_task(file.path, 'stdin', arguments).value)
          .to eq("message_one" => "Hello from task", "message_two" => "Goodbye")
      end
    end

    context "requesting a pty" do
      let(:config) do
        Bolt::Config.new(transports: { ssh: {
                           insecure: true,
                           sudo: true,
                           sudo_password: password,
                           run_as: 'root',
                           tty: true
                         } })
      end

      it "can execute a command when a tty is requested", ssh: true do
        expect(ssh._run_command('whoami').stdout).to eq("\r\nroot\r\n")
      end
    end

    context "with an incorrect password" do
      let(:config) {
        Bolt::Config.new(transports: { ssh: {
                           insecure: true,
                           sudo: true,
                           sudo_password: 'nonsense',
                           run_as: 'root'
                         } })
      }
      let(:ssh) { Bolt::SSH.new(hostname, port, user, password, uri: 'foo', config: config) }

      it "returns a failed result", ssh: true do
        expect(ssh._run_command('whoami').error).to eq(
          'kind' => 'puppetlabs.tasks/escalate-error',
          'msg' => "Sudo password for user #{user} not recognized on foo",
          'details' => {},
          'issue_code' => 'BAD_PASSWORD'
        )
      end
    end

    context "with no password" do
      let(:config) do
        Bolt::Config.new(transports: { ssh: {
                           insecure: true,
                           sudo: true,
                           run_as: 'root'
                         } })
      end
      let(:ssh) { Bolt::SSH.new(hostname, port, user, password, uri: 'foo', config: config) }

      it "returns a failed result", ssh: true do
        expect(ssh._run_command('whoami').error).to eq(
          'kind' => 'puppetlabs.tasks/escalate-error',
          'msg' => "Sudo password for user #{user} was not provided for foo",
          'details' => {},
          'issue_code' => 'NO_PASSWORD'
        )
      end
    end
  end
end
