require 'spec_helper'
require 'bolt/transports'
require 'bolt/transports/winrm'

describe "winrm thingy" do
  let(:endpoint) { "http://localhost:55985/wsman" }
  let(:user) { "vagrant" }
  let(:password) { "vagrant" }
  let(:command) { "echo $env:UserName" }

  it "executes a command on a host", vagrant: true do
    expect {
      Bolt::Transports::WinRM.execute(endpoint, user, command, password)
    }.to output("vagrant\r\n").to_stdout
  end
end
