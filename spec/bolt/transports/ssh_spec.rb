require 'spec_helper'
require 'bolt/transports'
require 'bolt/transports/ssh'

describe Bolt::Transports::SSH do
  let(:hostname) { "localhost" }
  let(:user) { "vagrant" }
  let(:password) { "vagrant" }
  let(:port) { 2224 }
  let(:command) { "pwd" }
  let(:ssh) { Bolt::Transports::SSH.new(hostname, user, port, password) }

  it "executes a command on a host", vagrant: true do
    expect {
      ssh.execute(command)
    }.to output("/home/vagrant\n").to_stdout
  end
end
