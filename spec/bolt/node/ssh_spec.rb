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

  before(:each) { ssh.connect }
  after(:each) { ssh.disconnect }

  it "executes a command on a host", vagrant: true do
    expect(ssh.execute(command).value).to eq("/home/vagrant\n")
  end

  it "captures stderr from a host", vagrant: true do
    expect(ssh.execute("ssh -V").output.stderr.string).to match(/OpenSSH/)
  end

  it "can copy a file to a host", vagrant: true do
    contents = "kljhdfg"
    with_tempfile_containing('copy-test', contents) do |file|
      ssh.copy(file.path, "/home/vagrant/copy-test")

      expect(ssh.execute("cat /home/vagrant/copy-test").value).to eq(contents)

      ssh.execute("rm /home/vagrant/copy-test")
    end
  end

  it "can run a script remotely", vagrant: true do
    contents = "#!/bin/sh\necho hellote"
    with_tempfile_containing('script test', contents) do |file|
      expect(ssh.run_script(file.path).value).to eq("hellote\n")
    end
  end

  it "can run a task", vagrant: true do
    contents = "#!/bin/sh\necho -n ${PT_message_one} ${PT_message_two}"
    arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
    with_tempfile_containing('tasks test', contents) do |file|
      expect(ssh.run_task(file.path, 'environment', arguments).value)
        .to eq('Hello from task Goodbye')
    end
  end

  it "can run a task passing input on stdin", vagrant: true do
    contents = "#!/bin/sh\ngrep 'message_one'"
    arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
    with_tempfile_containing('tasks test stdin', contents) do |file|
      expect(ssh.run_task(file.path, 'stdin', arguments).value)
        .to match(/{"message_one":"Hello from task","message_two":"Goodbye"}/)
    end
  end

  it "can run a task passing input on stdin and environment", vagrant: true do
    contents = <<END
#!/bin/sh
echo -n ${PT_message_one} ${PT_message_two}
grep 'message_one'
END
    arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
    with_tempfile_containing('tasks-test-both', contents) do |file|
      expect(ssh.run_task(file.path, 'both', arguments).value).to eq(<<END)
Hello from task Goodbye{\"message_one\":\
\"Hello from task\",\"message_two\":\"Goodbye\"}
END
    end
  end
end
