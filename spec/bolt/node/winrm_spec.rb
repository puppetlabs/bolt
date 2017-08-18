require 'spec_helper'
require 'puppet_bolt/node'
require 'puppet_bolt/node/winrm'

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

  it "can copy a file to a host", vagrant: true do
    contents = "934jklnvf"
    remote_path = 'C:\Users\vagrant\copy-test-winrm'
    Tempfile.open('copy-test-winrm') do |file|
      file.write(contents)
      file.flush
      winrm.connect
      winrm.copy(file.path, remote_path)

      expect {
        winrm.execute("type #{remote_path}")
      }.to output("#{contents}\r\n").to_stdout

      winrm.execute("del #{remote_path}")
      winrm.disconnect
    end
  end
end
