require 'spec_helper'
require 'bolt_spec/errors'
require 'bolt_spec/files'
require 'bolt/node'
require 'bolt/node/winrm'
require 'httpclient'

describe Bolt::WinRM do
  include BoltSpec::Errors
  include BoltSpec::Files

  let(:host) { ENV['BOLT_WINRM_HOST'] || 'localhost' }
  let(:port) { ENV['BOLT_WINRM_PORT'] || 55985 }
  let(:user) { ENV['BOLT_WINRM_USER'] || "vagrant" }
  let(:password) { ENV['BOLT_WINRM_PASSWORD'] || "vagrant" }
  let(:command) { "echo $env:UserName" }
  let(:winrm) { Bolt::WinRM.new(host, port, user, password) }
  let(:echo_script) { <<PS }
foreach ($i in $args)
{
    Write-Host $i
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

  context "when connecting fails", winrm: true do
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

  it "executes a command on a host", winrm: true do
    expect(winrm.execute(command).stdout.string).to eq("#{user}\r\n")
  end

  it "reuses a PowerShell host / runspace for multiple commands", winrm: true do
    contents = [
      "$Host.InstanceId.ToString(), $Host.Runspace.InstanceId.ToString()",
      "$ENV:A, $B, $script:C, $local:D, $global:E",
      "$ENV:A = 'env'",
      "$B = 'unscoped'",
      "$script:C = 'script'",
      "$local:D = 'local'",
      "$global:E = 'global'",
      "$ENV:A, $B, $script:C, $local:D, $global:E"
    ].join('; ')

    result = winrm.execute(contents)
    instance, runspace, *outputs = result.stdout.string.split("\r\n")

    result2 = winrm.execute(contents)
    instance2, runspace2, *outputs2 = result2.stdout.string.split("\r\n")

    # Host should be identical (uniquely identified by Guid)
    expect(instance).to eq(instance2)
    # Runspace should be identical (uniquely identified by Guid)
    expect(runspace).to eq(runspace2)

    # state not yet set, only get one copy
    expect(outputs).to eq(%w[env unscoped script local global])

    # state carries across invocations, get 2 copies
    outs = %w[env unscoped script local global env unscoped script local global]
    expect(outputs2).to eq(outs)
  end

  it "can upload a file to a host", winrm: true do
    contents = "934jklnvf"
    remote_path = 'C:\Windows\Temp\upload-test-winrm'
    with_tempfile_containing('upload-test-winrm', contents) do |file|
      winrm.upload(file.path, remote_path)

      expect(
        winrm.execute("type #{remote_path}").stdout.string
      ).to eq("#{contents}\r\n")

      winrm.execute("del #{remote_path}")
    end
  end

  it "can run a PowerShell script remotely", winrm: true do
    contents = "Write-Output \"hellote\""
    with_tempfile_containing('script-test-winrm', contents) do |file|
      expect(
        winrm._run_script(file.path, []).stdout
      ).to eq("hellote\r\n")
    end
  end

  it "reuses the host for multiple PowerShell scripts", winrm: true do
    contents = <<-PS
      $Host.InstanceId.ToString(), $Host.Runspace.InstanceId.ToString()

      $ENV:A, $B, $script:C, $local:D, $global:E

      $ENV:A = 'env'
      $B = 'unscoped'
      $script:C = 'script'
      $local:D = 'local'
      $global:E = 'global'

      $ENV:A, $B, $script:C, $local:D, $global:E
    PS

    with_tempfile_containing('script-test-winrm', contents) do |file|
      result = winrm._run_script(file.path, [])
      instance, runspace, *outputs = result.stdout.split("\r\n")

      result2 = winrm._run_script(file.path, [])
      instance2, runspace2, *outputs2 = result2.stdout.split("\r\n")

      # scripts execute in a completely new process
      # Host unique Guid is different
      expect(instance).to eq(instance2)
      # Runspace unique Guid is different
      expect(runspace).to eq(runspace2)

      # state not yet set, only get one copy
      expect(outputs).to eq(%w[env unscoped script local global])

      # environment variable remains set
      # as do script and global given use of Invoke-Command
      outs = %w[env script global env unscoped script local global]
      expect(outputs2).to eq(outs)
    end
  end

  it "can run a PowerShell script remotely with quoted args", winrm: true do
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
        ).stdout
      ).to eq(<<QUOTED)
nospaces\r
with spaces\r
'a b'\r
'a b'\r
a 'b' c\r
a 'b' c\r
QUOTED
    end
  end

  it "correctly passes embedded double quotes to PowerShell", winrm: true do
    with_tempfile_containing('script-test-winrm-psquote', echo_script) do |file|
      expect(
        winrm._run_script(
          file.path,
          ["\"a b\"",
           '"a b"',
           "a \"b\" c",
           'a "b" c']
        ).stdout
      ).to eq(<<QUOTED)
"a b"\r
"a b"\r
a "b" c\r
a "b" c\r
QUOTED
    end
  end

  it "escapes unsafe shellwords", winrm: true do
    with_tempfile_containing('script-test-winrm-escape', echo_script) do |file|
      expect(
        winrm._run_script(
          file.path,
          ['echo $env:path']
        ).stdout
      ).to eq(<<SHELLWORDS)
echo $env:path\r
SHELLWORDS
    end
  end

  it "does not deadlock scripts that write > 4k to stderr", winrm: true do
    contents = <<-PS
    $bytes_in_k = (1024 * 4) + 1
    $Host.UI.WriteErrorLine([Text.Encoding]::UTF8.GetString((New-Object Byte[] ($bytes_in_k))))
    PS

    with_tempfile_containing('script-test-winrm', contents) do |file|
      result = winrm._run_script(file.path, [])
      expect(result).to be_success
      expected_nulls = ("\0" * (1024 * 4 + 1)) + "\r\n"
      expect(result.stderr).to eq(expected_nulls)
    end
  end

  it "can run a task remotely", winrm: true do
    contents = 'Write-Host "$env:PT_message_one ${env:PT_message two}"'
    arguments = { :message_one => 'task is running',
                  :"message two" => 'task has run' }
    with_tempfile_containing('task-test-winrm', contents) do |file|
      expect(winrm._run_task(file.path, 'environment', arguments).message)
        .to eq("task is running task has run\r\n")
    end
  end

  it "will collect stdout using valid PowerShell output methods", winrm: true do
    contents = <<-PS
    # explicit Format-Table for PS5+ overrides implicit Format-Table which
    # includes a 300ms delay waiting for more pipeline output
    # https://github.com/PowerShell/PowerShell/issues/4594
    Write-Output "message 1" | Format-Table

    Write-Host "message 2"
    "message 3" | Out-Host
    $Host.UI.WriteLine("message 4")

    # Console::WriteLine doesn't work in WinRMs ServerRemoteHost
    [Console]::WriteLine("message 5")

    # preference variable must be set to show Information messages
    $InformationPreference = 'Continue'
    Write-Information "message 6"
    PS

    with_tempfile_containing('stdout-test-winrm', contents) do |file|
      expect(
        winrm._run_script(file.path, []).stdout
      ).to eq([
        "message 1\r\n",
        "message 2\r\n",
        "message 3\r\n",
        "message 4\r\n",
        "message 6\r\n"
      ].join(''))
    end
  end

  it "can run a task passing input on stdin", winrm: true do
    contents = <<PS
$line = [Console]::In.ReadLine()
Write-Host $line
PS
    arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
    with_tempfile_containing('tasks-test-stdin-winrm', contents) do |file|
      expect(winrm._run_task(file.path, 'stdin', arguments).value)
        .to eq("message_one" => "Hello from task", "message_two" => "Goodbye")
    end
  end

  it "can run a task passing input on stdin and environment", winrm: true do
    contents = <<PS
Write-Host "$env:PT_message_one $env:PT_message_two"
$line = [Console]::In.ReadLine()
Write-Host $line
PS
    arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
    with_tempfile_containing('tasks-test-both-winrm', contents) do |file|
      expect(
        winrm._run_task(file.path, 'both', arguments).message
      ).to eq([
        "Hello from task Goodbye\r\n",
        "{\"message_one\":\"Hello from task\",\"message_two\":\"Goodbye\"}\r\n"
      ].join(''))
    end
  end

  describe "when determining result" do
    it "fails to run a .pp task without Puppet agent installed", winrm: true do
      with_tempfile_containing('task-pp-winrm', "notice('hi')", '.pp') do |file|
        result = winrm._run_task(file.path, 'stdin', {})
        expect(result).to_not be_success
      end
    end

    it "fails when a PowerShell script exits with a code", winrm: true do
      contents = <<-PS
      exit 42
      PS

      with_tempfile_containing('script-test-winrm', contents) do |file|
        result = winrm._run_script(file.path, [])
        expect(result).to_not be_success
        expect(result.exit_code).to eq(42)
      end
    end

    context "fails for PowerShell terminating errors: " do
      it "exception thrown", winrm: true do
        contents = <<-PS
        throw "My Error"
        PS

        with_tempfile_containing('script-test-winrm', contents) do |file|
          result = winrm._run_script(file.path, [])
          expect(result).to_not be_success
          expect(result.exit_code).to eq(1)
        end
      end

      it "Write-Error and $ErrorActionPreference Stop", winrm: true do
        contents = <<-PS
        $ErrorActionPreference = 'Stop'
        Write-Error "error stream addition"
        PS

        with_tempfile_containing('script-test-winrm', contents) do |file|
          result = winrm._run_script(file.path, [])
          expect(result).to_not be_success
        end
      end

      it "ParserError Code (IncompleteParseException)", winrm: true do
        contents = '{'

        with_tempfile_containing('script-test-winrm', contents) do |file|
          result = winrm._run_script(file.path, [])
          expect(result).to_not be_success
        end
      end

      it "ParserError Code", winrm: true do
        contents = <<-PS
        if (1 -badop 2) { Write-Out 'hi' }
        PS

        with_tempfile_containing('script-test-winrm', contents) do |file|
          result = winrm._run_script(file.path, [])
          expect(result).to_not be_success
        end
      end

      it "Correct syntax bad command (CommandNotFoundException)", winrm: true do
        contents = <<-PS
        Foo-Bar
        PS

        with_tempfile_containing('script-test-winrm', contents) do |file|
          result = winrm._run_script(file.path, [])
          expect(result).to_not be_success
        end
      end
    end

    context "does not fail for PowerShell non-terminating errors:" do
      it "Write-Error with default $ErrorActionPreference", winrm: true do
        contents = <<-PS
        Write-Error "error stream addition"
        PS

        with_tempfile_containing('script-test-winrm', contents) do |file|
          result = winrm._run_script(file.path, [])
          expect(result).to be_success
        end
      end

      it "Calling a failing external binary", winrm: true do
        # deriving meaning from $LASTEXITCODE requires a custom PS host
        contents = <<-PS
        cmd.exe /c "exit 42"
        # for desired behavior, a user must explicitly call
        # exit $LASTEXITCODE
        PS

        with_tempfile_containing('script-test-winrm', contents) do |file|
          result = winrm._run_script(file.path, [])
          expect(result).to be_success
        end
      end
    end
  end

  describe "when resolving file extensions" do
    let(:output) do
      output = Bolt::Node::Output.new
      output.stdout << "42"
      output.exit_code = 0
      output
    end

    it "can apply a powershell-based task", winrm: true do
      contents = <<PS
Write-Output "42"
PS
      allow(winrm)
        .to receive(:execute_process)
        .with('powershell.exe',
              ['-NoProfile', '-NonInteractive', '-NoLogo',
               '-ExecutionPolicy', 'Bypass', '-File', /^".*"$/],
              anything)
        .and_return(output)
      with_tempfile_containing('task-ps1-winrm', contents, '.ps1') do |file|
        expect(
          winrm._run_task(file.path, 'stdin', {}).message
        ).to eq("42")
      end
    end

    it "can apply a ruby-based script", winrm: true do
      allow(winrm)
        .to receive(:execute_process)
        .with('ruby.exe',
              ['-S', /^".*"$/])
        .and_return(output)
      with_tempfile_containing('script-rb-winrm', "puts 42", '.rb') do |file|
        expect(
          winrm._run_script(file.path, []).stdout
        ).to eq("42")
      end
    end

    it "can apply a ruby-based task", winrm: true do
      allow(winrm)
        .to receive(:execute_process)
        .with('ruby.exe',
              ['-S', /^".*"$/],
              anything)
        .and_return(output)
      with_tempfile_containing('task-rb-winrm', "puts 42", '.rb') do |file|
        expect(
          winrm._run_task(file.path, 'stdin', {}).message
        ).to eq("42")
      end
    end

    it "can apply a puppet manifest for a '.pp' script", winrm: true do
      stdout = <<OUTPUT
Notice: Scope(Class[main]): hi
Notice: Compiled catalog for x.y.z in environment production in 0.04 seconds
Notice: Applied catalog in 0.04 seconds
OUTPUT
      output = Bolt::Node::Output.new
      output.stdout << stdout
      output.exit_code = 0

      allow(winrm)
        .to receive(:execute_process)
        .with('puppet.bat',
              ['apply', /^".*"$/])
        .and_return(output)
      contents = "notice('hi')"
      with_tempfile_containing('script-pp-winrm', contents, '.pp') do |file|
        expect(
          winrm._run_script(file.path, []).stdout
        ).to eq(stdout)
      end
    end

    it "can apply a puppet manifest for a '.pp' task", winrm: true do
      allow(winrm)
        .to receive(:execute_process)
        .with('puppet.bat',
              ['apply', /^".*"$/],
              anything)
        .and_return(output)
      with_tempfile_containing('task-pp-winrm', "notice('hi')", '.pp') do |file|
        expect(
          winrm._run_task(file.path, 'stdin', {}).message
        ).to eq("42")
      end
    end

    it "returns a friendly stderr msg with puppet.bat missing", winrm: true do
      with_tempfile_containing('task-pp-winrm', "notice('hi')", '.pp') do |file|
        result = winrm._run_task(file.path, 'stdin', {})
        stderr = result.error['msg']
        expect(stderr).to match(/^Could not find executable 'puppet\.bat'/)
        expect(stderr).to_not match(/CommandNotFoundException/)
      end
    end
  end
end
