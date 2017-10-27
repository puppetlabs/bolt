require 'spec_helper'
require 'bolt_spec/errors'
require 'bolt_spec/files'
require 'bolt/node'
require 'bolt/node/winrm'
require 'httpclient'

describe Bolt::WinRM do
  include BoltSpec::Errors
  include BoltSpec::Files

  let(:host) { 'localhost' }
  let(:port) { 55985 }
  let(:user) { "vagrant" }
  let(:password) { "vagrant" }
  let(:command) { "echo $env:UserName" }
  let(:winrm) { Bolt::WinRM.new(host, port, user, password) }
  let(:echo_script) { <<PS }
foreach ($i in $args)
{
    Write-Output $i
}
PS

  before(:each) { winrm.connect }
  after(:each) { winrm.disconnect }

  def stub_winrm_to_raise(klass, message)
    shell = double('powershell')
    allow_any_instance_of(WinRM::Connection)
      .to receive(:shell).and_return(shell)
    allow(shell).to receive(:run).and_raise(klass, message)
  end

  context "when connecting fails", vagrant: true do
    it "raises Node::ConnectError if the node name can't be resolved" do
      winrm = Bolt::WinRM.new('totally-not-there', port, user, password)
      expect_node_error(Bolt::Node::ConnectError,
                        'CONNECT_ERROR',
                        /Failed to connect to/) do
        winrm.connect
      end
    end

    it "raises Node::ConnectError if the connection is refused" do
      winrm = Bolt::WinRM.new(host, 65535, user, password)

      stub_winrm_to_raise(
        Errno::ECONNREFUSED,
        "Connection refused - connect(2) for \"#{host}\" port #{port}"
      )

      expect_node_error(Bolt::Node::ConnectError,
                        'CONNECT_ERROR',
                        /Failed to connect to/) do
        winrm.connect
      end
    end

    it "raises Node::ConnectError if the connection times out" do
      winrm = Bolt::WinRM.new(host, port, user, password)
      stub_winrm_to_raise(HTTPClient::ConnectTimeoutError, 'execution expired')

      expect_node_error(Bolt::Node::ConnectError,
                        'CONNECT_ERROR',
                        /Failed to connect to/) do
        winrm.connect
      end
    end

    it "raises Node::ConnectError if authentication fails" do
      winrm = Bolt::WinRM.new(host, port, user, 'whoops wrong password')

      stub_winrm_to_raise(::WinRM::WinRMAuthorizationError, "")

      expect_node_error(
        Bolt::Node::ConnectError, 'AUTH_ERROR',
        %r{Authentication failed for http://#{host}:#{port}/wsman}
      ) do
        winrm.connect
      end
    end

    it "raises Node::ConnectError if user is absent" do
      winrm = Bolt::WinRM.new(host, port, nil, password)

      expect_node_error(
        Bolt::Node::ConnectError, 'CONNECT_ERROR',
        /Failed to connect to .*: user is a required option/
      ) do
        winrm.connect
      end
    end

    it "raises Node::ConnectError if password is absent" do
      winrm = Bolt::WinRM.new(host, port, user, nil)

      expect_node_error(
        Bolt::Node::ConnectError, 'CONNECT_ERROR',
        /Failed to connect to .*: password is a required option/
      ) do
        winrm.connect
      end
    end
  end

  it "executes a command on a host", vagrant: true do
    expect(winrm.execute(command).value).to eq("vagrant\r\n")
  end

  it "can upload a file to a host", vagrant: true do
    contents = "934jklnvf"
    remote_path = 'C:\Users\vagrant\upload-test-winrm'
    with_tempfile_containing('upload-test-winrm', contents) do |file|
      winrm.upload(file.path, remote_path)

      expect(
        winrm.execute("type #{remote_path}").value
      ).to eq("#{contents}\r\n")

      winrm.execute("del #{remote_path}")
    end
  end

  it "can run a script remotely", vagrant: true do
    contents = "Write-Output \"hellote\""
    with_tempfile_containing('script-test-winrm', contents) do |file|
      expect(
        winrm._run_script(file.path, []).value
      ).to eq("hellote\r\n\r\n")
    end
  end

  it "can run a script remotely with quoted arguments", vagrant: true do
    with_tempfile_containing('script-test-winrm-quotes', echo_script) do |file|
      expect(
        winrm._run_script(
          file.path,
          ['nospaces',
           'with spaces',
           "'a b'",
           '\'a b\'',
           "a 'b' c",
           'a \'b\' c']
        ).value
      ).to eq(<<QUOTED)
nospaces\r
with spaces\r
'a b'\r
'a b'\r
a 'b' c\r
a 'b' c\r
\r
QUOTED
    end
  end

  it "loses track of embedded double quotes", vagrant: true do
    with_tempfile_containing('script-test-winrm-buggy', echo_script) do |file|
      expect(
        winrm._run_script(
          file.path,
          ["\"a b\"",
           '"a b"',
           "a \"b\" c",
           'a "b" c']
        ).value
      ).to eq(<<QUOTED)
a\r
b\r
a\r
b\r
a b c\r
a b c\r
\r
QUOTED
    end
  end

  it "escapes unsafe shellwords", vagrant: true do
    with_tempfile_containing('script-test-winrm-escape', echo_script) do |file|
      expect(
        winrm._run_script(
          file.path,
          ['echo $env:path']
        ).value
      ).to eq(<<SHELLWORDS)
echo $env:path\r
\r
SHELLWORDS
    end
  end

  it "can run a task remotely", vagrant: true do
    contents = 'Write-Output "$env:PT_message_one" ${env:PT_message two}'
    arguments = { :message_one => 'task is running',
                  :"message two" => 'task has run' }
    with_tempfile_containing('task-test-winrm', contents) do |file|
      expect(winrm._run_task(file.path, 'environment', arguments).value)
        .to eq("task is running\r\ntask has run\r\n\r\n")
    end
  end

  it "can run a task passing input on stdin", vagrant: true do
    contents = <<PS
$line = [Console]::In.ReadLine()
Write-Output $line
PS
    arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
    with_tempfile_containing('tasks-test-stdin-winrm', contents) do |file|
      expect(winrm._run_task(file.path, 'stdin', arguments).value)
        .to match(/{"message_one":"Hello from task","message_two":"Goodbye"}/)
    end
  end

  it "can run a task passing input on stdin and environment", vagrant: true do
    contents = <<PS
Write-Output "$env:PT_message_one" "$env:PT_message_two"
$line = [Console]::In.ReadLine()
Write-Output $line
PS
    arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
    with_tempfile_containing('tasks-test-both-winrm', contents) do |file|
      expect(
        winrm._run_task(file.path, 'both', arguments).value
      ).to eq(['Hello from task',
               'Goodbye',
               '{"message_one":"Hello from task","message_two":"Goodbye"}',
               "\r\n"].join("\r\n"))
    end
  end

  it "can apply a puppet manifest for a '.pp' task", vagrant: true do
    output = <<OUTPUT
Notice: Scope(Class[main]): hi
Notice: Compiled catalog for x.y.z in environment production in 0.04 seconds
Notice: Applied catalog in 0.04 seconds
OUTPUT
    allow(winrm)
      .to receive(:execute_process)
      .with("C:\\Program Files\\Puppet Labs\\Puppet\\bin\\puppet.bat",
            /apply/,
            anything)
      .and_return(Bolt::Node::Success.new(output))
    with_tempfile_containing('task-pp-winrm', "notice('hi)", '.pp') do |file|
      expect(
        winrm._run_task(file.path, 'stdin', {}).value
      ).to eq(output)
    end
  end
end
