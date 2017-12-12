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
  let(:ssl_port) { ENV['BOLT_WINRM_SSL_PORT'] || 55986 }
  let(:user) { ENV['BOLT_WINRM_USER'] || "vagrant" }
  let(:password) { ENV['BOLT_WINRM_PASSWORD'] || "vagrant" }
  let(:command) { "echo $env:UserName" }
  let(:config) { Bolt::Config.new(transports: { winrm: { insecure: true } }) }
  let(:ssl_config) { Bolt::Config.new(transports: { winrm: { ca_cert: 'resources/cert.pem' } }) }
  let(:winrm) { Bolt::WinRM.new(host, port, user, password, config: config) }
  let(:winrm_ssl) { Bolt::WinRM.new(host, ssl_port, user, password, config: ssl_config) }
  let(:echo_script) { <<PS }
foreach ($i in $args)
{
    Write-Host $i
}
PS

  def stub_winrm_to_raise(klass, message)
    shell = double('powershell')
    allow_any_instance_of(WinRM::Connection)
      .to receive(:shell).and_return(shell)
    allow(shell).to receive(:run).and_raise(klass, message)
  end

  context "when connecting fails", winrm: true do
    it "raises Node::ConnectError if the connection is refused" do
      port = TCPServer.open(0) { |socket| socket.addr[1] }
      winrm = Bolt::WinRM.new(host, port, user, password)

      # The connection should fail immediately; this timeout helps ensure that
      # and avoids a hang
      Timeout.timeout(3) do
        expect_node_error(Bolt::Node::ConnectError,
                          'CONNECT_ERROR',
                          /Failed to connect to/) do
          winrm.connect
        end
      end
    end

    it "raises Node::ConnectError if the node name can't be resolved" do
      winrm = Bolt::WinRM.new('totally-not-there', port, user, password, config: config)
      exec_time = Time.now
      expect_node_error(Bolt::Node::ConnectError,
                        'CONNECT_ERROR',
                        /Failed to connect to/) do
        winrm.connect
      end
      exec_time = Time.now - exec_time
      expect(exec_time).to be < 1
    end

    it "adheres to the specified timeout" do
      TCPServer.open(0) do |server|
        port = server.addr[1]

        config[:transports][:winrm][:connect_timeout] = 2
        winrm = Bolt::WinRM.new(host, port, user, password, config: config)

        Timeout.timeout(3) do
          expect_node_error(Bolt::Node::ConnectError,
                            'CONNECT_ERROR',
                            /Timeout after \d+ seconds connecting to/) do
            winrm.connect
          end
        end
      end
    end

    it "raises Node::ConnectError if authentication fails" do
      winrm = Bolt::WinRM.new(host, port, user, 'whoops wrong password', config: config)

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

  context "connecting over SSL" do
    it "executes a command on a host", winrm: true do
      winrm_ssl.connect
      expect(winrm_ssl.execute(command).stdout.string).to eq("#{user}\r\n")
    end
  end

  context "with an open connection" do
    before(:each) { winrm.connect }
    after(:each) { winrm.disconnect }

    it "executes a command on a host", winrm: true do
      expect(winrm.execute(command).stdout.string).to eq("#{user}\r\n")
    end

    it "reuses a PowerShell host / runspace for multiple commands", winrm: true do
      contents = [
        "$Host.InstanceId.ToString()",
        "if ($Host.Runspace.InstanceId) { $Host.Runspace.InstanceId.ToString()} else { 'noid' }",
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
        $Host.InstanceId.ToString()
        if ($Host.Runspace.InstanceId) { $Host.Runspace.InstanceId.ToString()} else { 'noid' }

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

    it "supports the powershell input method", winrm: true do
      contents = <<-PS
        param ($Name, $Age, $Height)

        Write-Host @"
Name: $Name ($(if ($Name -ne $null) { $Name.GetType().Name } else { 'null' }))
Age: $Age ($(if ($Age -ne $null) { $Age.GetType().Name } else { 'null' }))
Height: $Height ($(if ($Height -ne $null) { $Height.GetType().Name } else { 'null' }))
"@
      PS
      # note that the order of the entries in this hash is not the same as
      # the order of the task parameters
      arguments = { Age: 30,
                    Height: 5.75,
                    Name: 'John Doe' }
      with_tempfile_containing('task-params-test-winrm.ps1', contents) do |file|
        expect(winrm._run_task(file.path, 'powershell', arguments).message)
          .to match(/\AName: John Doe \(String\).*^Age: 30 \(Int\d+\).*^Height: 5.75 \((Double|Decimal)\).*\Z/m)
      end
    end

    it "fails when the powershell input method is used to pass unexpected parameters to a task", winrm: true do
      contents = <<-PS
        param (
          [Parameter()]
          [String]$foo
        )

        $bar = $env:PT_bar
        Write-Host `
          "foo: $foo ($(if ($foo -ne $null) { $foo.GetType().Name } else { 'null' }))," `
          "bar: $bar ($(if ($bar -ne $null) { $bar.GetType().Name } else { 'null' }))"
      PS
      arguments = { bar: 30 } # note that the script doesn't recognize the 'bar' parameter
      with_tempfile_containing('task-params-test-winrm.ps1', contents) do |file|
        expect(winrm._run_task(file.path, 'powershell', arguments).error)
          .to_not be_nil
      end
    end

    it "succeeds when the environment input method is used to pass unexpected parameters to a task", winrm: true do
      contents = <<-PS
        param (
          [Parameter()]
          [String]$foo
        )

        $bar = $env:PT_bar
        Write-Host @"
foo: $foo ($(if ($foo -ne $null) { $foo.GetType().Name } else { 'null' }))
bar: $bar ($(if ($bar -ne $null) { $bar.GetType().Name } else { 'null' }))
"@
      PS
      arguments = { bar: 30 } # note that the script doesn't recognize the 'bar' parameter
      with_tempfile_containing('task-params-test-winrm.ps1', contents) do |file|
        expect(winrm._run_task(file.path, 'environment', arguments).message)
          .to match(/\Afoo:  \(String\).*^bar: 30 \(String\).*\Z/m) # note that $foo is an empty string and not null
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
      if ($PSVersionTable.PSVersion -ge [Version]'5.0.0') { Write-Information "message 6" }
      else { Write-Host "message 6" }
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

    describe "when tmpdir is specified", winrm: true do
      let(:tmpdir) { 'C:\mytmp' }
      let(:config) { Bolt::Config.new(transports: { winrm: { tmpdir: 'C:\mytmp', insecure: true } }) }
      let(:winrm) { Bolt::WinRM.new(host, port, user, password, config: config) }

      it 'uploads scripts to the specified tmpdir' do
        contents = "Write-Host $PSScriptRoot"
        with_tempfile_containing('script-test-winrm', contents) do |file|
          expect(winrm._run_script(file.path, []).stdout).to match(/#{Regexp.escape(tmpdir)}/)
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
end
