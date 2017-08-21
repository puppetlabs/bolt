require 'spec_helper'
require 'bolt/node'
require 'bolt/node/ssh'

describe Bolt::SSH do
  let(:hostname) { "localhost" }
  let(:user) { "vagrant" }
  let(:password) { "vagrant" }
  let(:port) { 2224 }
  let(:command) { "pwd" }
  let(:ssh) { Bolt::SSH.new(hostname, user, port, password) }

  it "executes a command on a host", vagrant: true do
    expect {
      ssh.connect
      ssh.execute(command)
      ssh.disconnect
    }.to output("/home/vagrant\n").to_stdout
  end

  it "can copy a file to a host", vagrant: true do
    contents = "kljhdfg"
    Tempfile.open('copy-test') do |file|
      file.write(contents)
      file.flush
      ssh.connect
      ssh.copy(file.path, "/home/vagrant/copy-test")

      expect {
        ssh.execute("cat /home/vagrant/copy-test")
      }.to output(contents).to_stdout

      ssh.execute("rm /home/vagrant/copy-test")
      ssh.disconnect
    end
  end

  it "can run a script remotely", vagrant: true do
    contents = <<-EOS
#!/bin/sh
echo "hellote"
EOS
    Tempfile.open('script test') do |file|
      file.write(contents)
      file.flush
      ssh.connect
      expect {
        ssh.run_script(file.path)
      }.to output("hellote\n").to_stdout
      ssh.disconnect
    end
  end
end
