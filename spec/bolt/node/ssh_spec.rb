require 'spec_helper'
require 'bolt_spec/errors'
require 'bolt_spec/files'
require 'bolt/node'
require 'bolt/node/ssh'
require 'bolt/config'

describe Bolt::SSH do
  include BoltSpec::Errors
  include BoltSpec::Files

  let(:hostname) { "localhost" }
  let(:user) { "vagrant" }
  let(:password) { "vagrant" }
  let(:port) { 2224 }
  let(:command) { "pwd" }
  let(:ssh) { Bolt::SSH.new(hostname, port, user, password) }
  let(:key) {
    { config: Bolt::Config.new(key: Dir[".vagrant/**/private_key"],
                               insecure: true) }
  }
  let(:insecure) { { config: Bolt::Config.new(insecure: true) } }
  let(:echo_script) { <<BASH }
for var in "$@"
do
    echo $var
done
BASH

  context "when connecting", vagrant: true do
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
      ssh = Bolt::SSH.new('totally-not-there', port)
      expect_node_error(Bolt::Node::ConnectError,
                        'CONNECT_ERROR',
                        /Failed to connect to/) do
        ssh.connect
      end
    end

    it "returns Node::ConnectError if the connection is refused" do
      ssh = Bolt::SSH.new(hostname, 65535, user, password)
      expect_node_error(Bolt::Node::ConnectError,
                        'CONNECT_ERROR',
                        /Failed to connect to/) do
        ssh.connect
      end
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
  end

  context "when executing with private key" do
    let(:ssh) { Bolt::SSH.new(hostname, port, user, **key) }

    before(:each) { ssh.connect }
    after(:each) { ssh.disconnect }

    it "executes a command on a host", vagrant: true do
      expect(ssh.execute(command).value).to eq("/home/vagrant\n")
    end

    it "captures stderr from a host", vagrant: true do
      expect(ssh.execute("ssh -V").output.stderr.string).to match(/OpenSSH/)
    end

    it "can upload a file to a host", vagrant: true do
      contents = "kljhdfg"
      with_tempfile_containing('upload-test', contents) do |file|
        ssh.upload(file.path, "/home/vagrant/upload-test")

        expect(
          ssh.execute("cat /home/vagrant/upload-test").value
        ).to eq(contents)

        ssh.execute("rm /home/vagrant/upload-test")
      end
    end

    it "can run a script remotely", vagrant: true do
      contents = "#!/bin/sh\necho hellote"
      with_tempfile_containing('script test', contents) do |file|
        expect(
          ssh._run_script(file.path, []).value
        ).to eq("hellote\n")
      end
    end

    it "can run a script remotely with quoted arguments", vagrant: true do
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
          ).value
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

    it "escapes unsafe shellwords in arguments", vagrant: true do
      with_tempfile_containing('script-test-ssh-escape', echo_script) do |file|
        expect(
          ssh._run_script(
            file.path,
            ['echo $HOME; cat /etc/passwd']
          ).value
        ).to eq(<<SHELLWORDS)
echo $HOME; cat /etc/passwd
SHELLWORDS
      end
    end

    it "can run a task", vagrant: true do
      contents = "#!/bin/sh\necho -n ${PT_message_one} ${PT_message_two}"
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_tempfile_containing('tasks test', contents) do |file|
        expect(ssh._run_task(file.path, 'environment', arguments).value)
          .to eq('Hello from task Goodbye')
      end
    end

    it "can run a task passing input on stdin", vagrant: true do
      contents = "#!/bin/sh\ngrep 'message_one'"
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_tempfile_containing('tasks test stdin', contents) do |file|
        expect(ssh._run_task(file.path, 'stdin', arguments).value)
          .to match(/{"message_one":"Hello from task","message_two":"Goodbye"}/)
      end
    end

    it "can run a task passing input on stdin and environment", vagrant: true do
      contents = <<SHELL
#!/bin/sh
echo -n ${PT_message_one} ${PT_message_two}
grep 'message_one'
SHELL
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_tempfile_containing('tasks-test-both', contents) do |file|
        expect(ssh._run_task(file.path, 'both', arguments).value).to eq(<<SHELL)
Hello from task Goodbye{\"message_one\":\
\"Hello from task\",\"message_two\":\"Goodbye\"}
SHELL
      end
    end
  end

  context "when executing" do
    let(:ssh) { Bolt::SSH.new(hostname, port, user, password, **insecure) }

    before(:each) { ssh.connect }
    after(:each) { ssh.disconnect }

    it "executes a command on a host", vagrant: true do
      expect(ssh.execute(command).value).to eq("/home/vagrant\n")
    end

    it "captures stderr from a host", vagrant: true do
      expect(ssh.execute("ssh -V").output.stderr.string).to match(/OpenSSH/)
    end

    it "can upload a file to a host", vagrant: true do
      contents = "kljhdfg"
      with_tempfile_containing('upload-test', contents) do |file|
        ssh.upload(file.path, "/home/vagrant/upload-test")

        expect(
          ssh.execute("cat /home/vagrant/upload-test").value
        ).to eq(contents)

        ssh.execute("rm /home/vagrant/upload-test")
      end
    end

    it "can run a script remotely", vagrant: true do
      contents = "#!/bin/sh\necho hellote"
      with_tempfile_containing('script test', contents) do |file|
        expect(
          ssh._run_script(file.path, []).value
        ).to eq("hellote\n")
      end
    end

    it "can run a script remotely with quoted arguments", vagrant: true do
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
          ).value
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

    it "escapes unsafe shellwords in arguments", vagrant: true do
      with_tempfile_containing('script-test-ssh-escape', echo_script) do |file|
        expect(
          ssh._run_script(
            file.path,
            ['echo $HOME; cat /etc/passwd']
          ).value
        ).to eq(<<SHELLWORDS)
echo $HOME; cat /etc/passwd
SHELLWORDS
      end
    end

    it "can run a task", vagrant: true do
      contents = "#!/bin/sh\necho -n ${PT_message_one} ${PT_message_two}"
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_tempfile_containing('tasks test', contents) do |file|
        expect(ssh._run_task(file.path, 'environment', arguments).value)
          .to eq('Hello from task Goodbye')
      end
    end

    it "can run a task passing input on stdin", vagrant: true do
      contents = "#!/bin/sh\ngrep 'message_one'"
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_tempfile_containing('tasks test stdin', contents) do |file|
        expect(ssh._run_task(file.path, 'stdin', arguments).value)
          .to match(/{"message_one":"Hello from task","message_two":"Goodbye"}/)
      end
    end

    it "can run a task passing input on stdin and environment", vagrant: true do
      contents = <<SHELL
#!/bin/sh
echo -n ${PT_message_one} ${PT_message_two}
grep 'message_one'
SHELL
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_tempfile_containing('tasks-test-both', contents) do |file|
        expect(ssh._run_task(file.path, 'both', arguments).value).to eq(<<SHELL)
Hello from task Goodbye{\"message_one\":\
\"Hello from task\",\"message_two\":\"Goodbye\"}
SHELL
      end
    end
  end
end
