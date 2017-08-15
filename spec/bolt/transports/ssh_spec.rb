require 'spec_helper'
require 'bolt/transports'
require 'bolt/transports/ssh'

describe "ssh thingy" do
  let(:hostname) { "localhost" }
  let(:user) { "vagrant" }
  let(:password) { "vagrant" }
  let(:port) { 2224 }
  let(:command) { "pwd" }

  it "executes a command on a host", vagrant: true do
    expect {
      Bolt::Transports::SSH.execute(hostname, user, command, port, password)
    }.to output("/home/vagrant\n").to_stdout
  end
end
