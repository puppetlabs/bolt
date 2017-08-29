require 'spec_helper'
require 'bolt_spec/files'
require 'bolt/node'
require 'bolt/node/winrm'

describe Bolt::WinRM do
  include BoltSpec::Files

  let(:host) { 'localhost' }
  let(:port) { 55985 }
  let(:user) { "vagrant" }
  let(:password) { "vagrant" }
  let(:command) { "echo $env:UserName" }
  let(:winrm) { Bolt::WinRM.new(host, port, user, password) }

  before(:each) { winrm.connect }
  after(:each) { winrm.disconnect }

  it "executes a command on a host", vagrant: true do
    expect(winrm.execute(command).value).to eq("vagrant\r\n")
  end

  it "can copy a file to a host", vagrant: true do
    contents = "934jklnvf"
    remote_path = 'C:\Users\vagrant\copy-test-winrm'
    with_tempfile_containing('copy-test-winrm', contents) do |file|
      winrm.copy(file.path, remote_path)

      expect(
        winrm.execute("type #{remote_path}").value
      ).to eq("#{contents}\r\n")

      winrm.execute("del #{remote_path}")
    end
  end

  it "can run a script remotely", vagrant: true do
    contents = 'Write-Output "hellote"'
    with_tempfile_containing('script-test-winrm', contents) do |file|
      expect(winrm.run_script(file.path).value).to match(/hellote\r\n/)
    end
  end

  it "can run a script remotely", vagrant: true do
    contents = 'Write-Output "$env:PT_message_one" ${env:PT_message two}'
    arguments = { :message_one => 'task is running',
                  :"message two" => 'task has run' }
    with_tempfile_containing('task-test-winrm', contents) do |file|
      expect(winrm.run_task(file.path, arguments).value)
        .to eq("task is running\r\ntask has run\r\n")
    end
  end
end
