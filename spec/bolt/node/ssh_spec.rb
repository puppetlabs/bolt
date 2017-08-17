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
      ssh.execute(command)
    }.to output("/home/vagrant\n").to_stdout
  end
end
