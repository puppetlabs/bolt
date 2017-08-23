require 'spec_helper'
require 'bolt_spec/files'
require 'bolt/node'
require 'bolt/node/winrm'

describe Bolt::WinRM do
  include BoltSpec::Files

  let(:endpoint) { "http://localhost:55985/wsman" }
  let(:user) { "vagrant" }
  let(:password) { "vagrant" }
  let(:command) { "echo $env:UserName" }
  let(:winrm) { Bolt::WinRM.new(endpoint, user, password) }

  before(:each) { winrm.connect }
  after(:each) { winrm.disconnect }

  it "executes a command on a host", vagrant: true do
    expect {
      winrm.execute(command)
    }.to output("vagrant\r\n").to_stdout
  end

  it "can copy a file to a host", vagrant: true do
    contents = "934jklnvf"
    remote_path = 'C:\Users\vagrant\copy-test-winrm'
    with_tempfile_containing('copy-test-winrm', contents) do |file|
      winrm.copy(file.path, remote_path)

      expect {
        winrm.execute("type #{remote_path}")
      }.to output("#{contents}\r\n").to_stdout

      winrm.execute("del #{remote_path}")
    end
  end

  it "can run a script remotely", vagrant: true do
    contents = 'Write-Output "hellote"'
    with_tempfile_containing('script-test-winrm', contents) do |file|
      expect {
        winrm.run_script(file.path)
      }.to output(/hellote\r\n/).to_stdout
    end
  end
end
