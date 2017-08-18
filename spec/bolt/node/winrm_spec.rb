require 'spec_helper'
require 'bolt/node'
require 'bolt/node/winrm'

describe "winrm thingy" do
  let(:endpoint) { "http://localhost:55985/wsman" }
  let(:user) { "vagrant" }
  let(:password) { "vagrant" }
  let(:command) { "echo $env:UserName" }
  let(:winrm) { Bolt::WinRM.new(endpoint, user, password) }

  it "executes a command on a host", vagrant: true do
    expect {
      winrm.connect
      winrm.execute(command)
      winrm.disconnect
    }.to output("vagrant\r\n").to_stdout
  end
end
