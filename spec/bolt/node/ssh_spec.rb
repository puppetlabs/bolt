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
  let(:ssh) { Bolt::SSH.new(hostname, user, port, password) }

  before(:each) { ssh.connect }
  after(:each) { ssh.disconnect }

  it "executes a command on a host", vagrant: true do
    expect {
      ssh.execute(command)
    }.to output("/home/vagrant\n").to_stdout
  end

  it "can copy a file to a host", vagrant: true do
    contents = "kljhdfg"
    with_tempfile_containing('copy-test', contents) do |file|
      ssh.copy(file.path, "/home/vagrant/copy-test")

      expect {
        ssh.execute("cat /home/vagrant/copy-test")
      }.to output(contents).to_stdout

      ssh.execute("rm /home/vagrant/copy-test")
    end
  end

  it "can run a script remotely", vagrant: true do
    contents = "#!/bin/sh\necho hellote"
    with_tempfile_containing('script test', contents) do |file|
      expect {
        ssh.run_script(file.path)
      }.to output("hellote\n").to_stdout
    end
  end
end
