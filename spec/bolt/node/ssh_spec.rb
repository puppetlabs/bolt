require 'spec_helper'
require 'bolt_spec/files'
require 'bolt/node'
require 'bolt/node/ssh'

describe Bolt::SSH do
  include BoltSpec::Files

  let(:hostname) { "localhost" }
  let(:user) { "vagrant" }
  let(:password) { "vagrant" }
  let(:port) { 2224 }
  let(:command) { "pwd" }
  let(:ssh) { Bolt::SSH.new(hostname, port, user, password) }

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
      ssh = Bolt::SSH.new(hostname, port, user, password, insecure: true)

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
      expect {
        ssh.connect
      }.to raise_error do |ex|
        expect(ex).to be_a(Bolt::Node::ConnectError)
        expect(ex.issue_code).to eq('HOST_KEY_ERROR')
        expect(ex.message).to match(/Host key verification failed/)
      end
    end

    it "returns Node::ConnectError if the node name can't be resolved" do
      ssh = Bolt::SSH.new('totally-not-there', port)
      expect {
        ssh.connect
      }.to raise_error do |ex|
        expect(ex).to be_a(Bolt::Node::ConnectError)
        expect(ex.issue_code).to eq('CONNECT_ERROR')
        expect(ex.message).to match(/Failed to connect to/)
      end
    end

    it "returns Node::ConnectError if the connection is refused" do
      ssh = Bolt::SSH.new(hostname, 65535, user, password, insecure: true)
      expect {
        ssh.connect
      }.to raise_error do |ex|
        expect(ex).to be_a(Bolt::Node::ConnectError)
        expect(ex.issue_code).to eq('CONNECT_ERROR')
        expect(ex.message).to match(/Failed to connect to/)
      end
    end
  end

  context "when executing" do
    let(:ssh) { Bolt::SSH.new(hostname, port, user, password, insecure: true) }

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
        expect(ssh._run_script(file.path).value).to eq("hellote\n")
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
