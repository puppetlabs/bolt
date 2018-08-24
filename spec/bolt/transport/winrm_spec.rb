# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/errors'
require 'bolt_spec/files'
require 'bolt_spec/task'
require 'bolt/transport/winrm'
require 'httpclient'
require 'winrm'

describe Bolt::Transport::WinRM do
  include BoltSpec::Errors
  include BoltSpec::Files
  include BoltSpec::Task

  let(:boltdir) { Bolt::Boltdir.new('.') }

  def mk_config(conf)
    stringified = conf.each_with_object({}) { |(k, v), coll| coll[k.to_s] = v }
    # The default of 10 seconds seems to be too short to always succeed in AppVeyor.
    stringified['connect-timeout'] ||= 20
    Bolt::Config.new(boltdir, 'transport' => 'winrm', 'winrm' => stringified)
  end

  let(:host) { ENV['BOLT_WINRM_HOST'] || 'localhost' }
  let(:port) { ENV['BOLT_WINRM_PORT'] || 25985 }
  let(:ssl_port) { ENV['BOLT_WINRM_SSL_PORT'] || 25986 }
  let(:user) { ENV['BOLT_WINRM_USER'] || "bolt" }
  let(:password) { ENV['BOLT_WINRM_PASSWORD'] || "bolt" }
  let(:command) { "echo $env:UserName" }
  let(:config) { mk_config(ssl: false, user: user, password: password) }
  let(:ssl_config) { mk_config(cacert: 'resources/ca.pem', user: user, password: password) }
  let(:winrm) { Bolt::Transport::WinRM.new }
  let(:winrm_ssl) { Bolt::Transport::WinRM.new }
  let(:echo_script) { <<PS }
foreach ($i in $args)
{
    Write-Host $i
}
PS

  def make_target(host_: host, port_: port, conf: config)
    Bolt::Target.new("#{host_}:#{port_}").update_conf(conf.transport_conf)
  end

  let(:target) { make_target }

  def stub_winrm_to_raise(klass, message)
    shell = double('powershell')
    allow_any_instance_of(WinRM::Connection)
      .to receive(:shell).and_return(shell)
    allow(shell).to receive(:run).and_raise(klass, message)
    allow(shell).to receive(:close)
  end

  context "when connecting fails", winrm: true do
    it "raises Node::ConnectError if the connection is refused" do
      port = TCPServer.open(0) { |socket| socket.addr[1] }

      # The connection should fail immediately; this timeout helps ensure that
      # and avoids a hang
      Timeout.timeout(3) do
        expect_node_error(Bolt::Node::ConnectError,
                          'CONNECT_ERROR',
                          /Failed to connect to/) do
          winrm.with_connection(make_target(host_: host, port_: port)) {}
        end
      end
    end

    it "raises Node::ConnectError if the node name can't be resolved" do
      exec_time = Time.now
      expect_node_error(Bolt::Node::ConnectError,
                        'CONNECT_ERROR',
                        /Failed to connect to/) do
        winrm.with_connection(make_target(host_: 'totally-not-there', conf: config)) {}
      end
      exec_time = Time.now - exec_time
      expect(exec_time).to be < 5
    end

    it "adheres to the specified timeout" do
      TCPServer.open(0) do |socket|
        port = socket.addr[1]
        config.transports[:winrm]['connect-timeout'] = 2

        Timeout.timeout(3) do
          expect_node_error(Bolt::Node::ConnectError,
                            'CONNECT_ERROR',
                            /Timeout after \d+ seconds connecting to/) do
            winrm.with_connection(make_target(host_: host, port_: port, conf: config)) {}
          end
        end
      end
    end

    context "authentication fails" do
      let(:password) { 'whoops wrong password' }

      it "raises Node::ConnectError" do
        stub_winrm_to_raise(::WinRM::WinRMAuthorizationError, "")

        expect_node_error(
          Bolt::Node::ConnectError, 'AUTH_ERROR',
          %r{Authentication failed for http://#{host}:#{port}/wsman}
        ) do
          winrm.with_connection(target) {}
        end
      end
    end

    context "user is absent" do
      let(:user) { nil }

      it "raises Node::ConnectError" do
        expect_node_error(
          Bolt::Node::ConnectError, 'CONNECT_ERROR',
          /Failed to connect to .*: user is a required option/
        ) do
          winrm.with_connection(target) {}
        end
      end
    end

    context "password is absent" do
      let(:password) { nil }

      it "raises Node::ConnectError" do
        expect_node_error(
          Bolt::Node::ConnectError, 'CONNECT_ERROR',
          /Failed to connect to .*: password is a required option/
        ) do
          winrm.with_connection(target) {}
        end
      end
    end
  end

  context "connecting over SSL", winrm: true do
    let(:target) { make_target(port_: ssl_port, conf: ssl_config) }

    it "executes a command on a host" do
      expect(winrm.run_command(target, command)['stdout']).to eq("#{user}\r\n")
    end

    it "can upload a file to a host" do
      contents = "kadejtw89894"
      remote_path = 'C:\Windows\Temp\upload-test-winrm-ssl'
      with_tempfile_containing('upload-test-winrm-ssl', contents, '.ps1') do |file|
        expect(
          winrm.upload(target, file.path, remote_path).value
        ).to eq(
          '_output' => "Uploaded '#{file.path}' to '#{target.host}:#{remote_path}'"
        )

        expect(
          winrm.run_command(target, "type #{remote_path}")['stdout']
        ).to eq("#{contents}\r\n")

        winrm.run_command(target, "del #{remote_path}")
      end
    end

    it "skips verification with ssl-verify: false" do
      target.options.delete('cacert')
      target.options['ssl-verify'] = false

      expect(winrm.run_command(target, command)['stdout']).to eq("#{user}\r\n")
    end
  end

  context "with an open connection" do
    it "executes a command on a host", winrm: true do
      expect(winrm.run_command(target, command)['stdout']).to eq("#{user}\r\n")
    end

    it "ignores _run_as", winrm: true do
      expect(winrm.run_command(target, command, '_run_as' => 'root')['stdout']).to eq("#{user}\r\n")
    end

    it "reuses a PowerShell host / runspace for multiple commands", winrm: true do
      pending("The code for this is in place, but in practice we reconnect for every command")
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

      result = winrm.run_command(target, contents)
      instance, runspace, *outputs = result['stdout'].split("\r\n")

      result2 = winrm.run_command(target, contents)
      instance2, runspace2, *outputs2 = result2['stdout'].split("\r\n")

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
      with_tempfile_containing('upload-test-winrm', contents, '.ps1') do |file|
        expect(
          winrm.upload(target, file.path, remote_path).value
        ).to eq(
          '_output' => "Uploaded '#{file.path}' to '#{target.host}:#{remote_path}'"
        )

        expect(
          winrm.run_command(target, "type #{remote_path}")['stdout']
        ).to eq("#{contents}\r\n")

        winrm.run_command(target, "del #{remote_path}")
      end
    end

    it "can run a PowerShell script remotely", winrm: true do
      contents = "Write-Output \"hellote\""
      with_tempfile_containing('script-test-winrm', contents, '.ps1') do |file|
        expect(
          winrm.run_script(target, file.path, [])['stdout']
        ).to eq("hellote\r\n")
      end
    end

    it "ignores _run_as", winrm: true do
      contents = "Write-Output \"hellote\""
      with_tempfile_containing('script-test-winrm', contents, '.ps1') do |file|
        expect(
          winrm.run_script(target, file.path, [], '_run_as' => 'root')['stdout']
        ).to eq("hellote\r\n")
      end
    end

    it "reuses the host for multiple PowerShell scripts", winrm: true do
      pending("The code for this is in place, but in practice we reconnect for every command")
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

      with_tempfile_containing('script-test-winrm', contents, '.ps1') do |file|
        result = winrm.run_script(target, file.path, [])
        instance, runspace, *outputs = result['stdout'].split("\r\n")

        result2 = winrm.run_script(target, file.path, [])
        instance2, runspace2, *outputs2 = result2['stdout'].split("\r\n")

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
      with_tempfile_containing('script-test-winrm-quotes', echo_script, '.ps1') do |file|
        expect(
          winrm.run_script(target,
                           file.path,
                           ['nospaces',
                            'with spaces',
                            "'a b'",
                            '\'a b\'',
                            "a 'b' c",
                            'a \'b\' c'])['stdout']
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
      with_tempfile_containing('script-test-winrm-psquote', echo_script, '.ps1') do |file|
        expect(
          winrm.run_script(target,
                           file.path,
                           ["\"a b\"",
                            '"a b"',
                            "a \"b\" c",
                            'a "b" c'])['stdout']
        ).to eq(<<QUOTED)
"a b"\r
"a b"\r
a "b" c\r
a "b" c\r
QUOTED
      end
    end

    it "can run a script with Sensitive arguments", winrm: true do
      arguments = ['non-sensitive-arg',
                   Sensitive.new('$ecret!')]
      with_tempfile_containing('script-sensitive-winrm', echo_script, '.ps1') do |file|
        expect(
          winrm.run_script(target, file.path, arguments)['stdout']
        ).to eq(<<QUOTED)
non-sensitive-arg\r
$ecret!\r
QUOTED
      end
    end

    it "escapes unsafe shellwords", winrm: true do
      with_tempfile_containing('script-test-winrm-escape', echo_script, '.ps1') do |file|
        expect(
          winrm.run_script(target,
                           file.path,
                           ['echo $env:path'])['stdout']
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

      with_tempfile_containing('script-test-winrm', contents, '.ps1') do |file|
        result = winrm.run_script(target, file.path, [])
        expect(result).to be_success
        expected_nulls = ("\0" * (1024 * 4 + 1)) + "\r\n"
        expect(result['stderr']).to eq(expected_nulls)
      end
    end

    it "does not reorder powershell output with lots of lines", winrm: true do
      contents = 'for ($i = 0; $i -le 4000; $i++) { Write-Host $i }'

      with_tempfile_containing('script-test-winrm', contents, '.ps1') do |file|
        result = winrm.run_script(target, file.path, [])
        expect(result).to be_success
        expected = (0..4000).to_a.join("\r\n")
        expect(result['stdout'].chomp).to eq(expected)
      end
    end

    context 'with a batch file' do
      let(:config) { mk_config(ssl: false, extensions: 'bat', user: user, password: password) }

      it "does not reorder output with lots of lines", winrm: true do
        contents = <<-BAT
        @echo off
        for /l %%x in (0, 1, 4000) do echo %%x
        BAT

        with_tempfile_containing('script-test-winrm', contents, '.bat') do |file|
          result = winrm.run_script(target, file.path, [])
          expect(result).to be_success
          expected = (0..4000).to_a.join("\r\n")
          expect(result['stdout'].chomp).to eq(expected)
        end
      end
    end

    it "can run a task remotely", winrm: true do
      contents = 'Write-Host "$env:PT_message_one ${env:PT_message two}"'
      arguments = { message_one: 'task is running',
                    "message two": 'task has run' }
      with_task_containing('task-test-winrm', contents, 'environment', '.ps1') do |task|
        expect(winrm.run_task(target, task, arguments).message)
          .to eq("task is running task has run\r\n")
      end
    end

    it "can run a task with arguments containing quotes", winrm: true do
      contents = 'Write-Host "$env:PT_message"'
      arguments = { message: "it's a hello world" }
      with_task_containing('task-test-winrm', contents, 'environment', '.ps1') do |task|
        expect(winrm.run_task(target, task, arguments).message)
          .to eq("it's a hello world\r\n")
      end
    end

    it "ignores _run_as", winrm: true do
      contents = 'Write-Host "$env:PT_message_one ${env:PT_message two}"'
      arguments = { message_one: 'task is running',
                    "message two": 'task has run' }
      with_task_containing('task-test-winrm', contents, 'environment', '.ps1') do |task|
        expect(winrm.run_task(target, task, arguments, '_run_as' => 'root').message)
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
      with_task_containing('task-params-test-winrm', contents, 'powershell', '.ps1') do |task|
        expect(winrm.run_task(target, task, arguments).message)
          .to match(/\AName: John Doe \(String\).*^Age: 30 \(Int\d+\).*^Height: 5.75 \((Double|Decimal)\).*\Z/m)
      end
    end

    it "ignores unexpected parameters when the powershell input method is used", winrm: true do
      contents = <<-PS
        param (
          [Parameter()]
          [String]$foo
        )

        Write-Host "foo=$foo"
      PS
      arguments = { foo: 30 } # note that the script doesn't recognize the 'bar' parameter
      with_task_containing('task-params-test-winrm', contents, 'powershell', '.ps1') do |task|
        expect(winrm.run_task(target, task, arguments).message).to eq("foo=30\r\n")
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
      with_task_containing('task-params-test-winrm', contents, 'environment', '.ps1') do |task|
        expect(winrm.run_task(target, task, arguments).message)
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

      with_tempfile_containing('stdout-test-winrm', contents, '.ps1') do |file|
        expect(
          winrm.run_script(target, file.path, [])['stdout']
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
      with_task_containing('tasks-test-stdin-winrm', contents, 'stdin', '.ps1') do |task|
        expect(winrm.run_task(target, task, arguments).value)
          .to eq("message_one" => "Hello from task", "message_two" => "Goodbye")
      end
    end

    it "can run a task passing input on environment", winrm: true do
      contents = <<PS
Write-Host "$env:PT_message_one $env:PT_message_two"
PS
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_task_containing('tasks-test-both-winrm', contents, 'environment', '.ps1') do |task|
        expect(
          winrm.run_task(target, task, arguments).message
        ).to eq("Hello from task Goodbye\r\n")
      end
    end

    it "serializes hashes as json in environment input", winrm: true do
      contents = "echo $env:PT_message"
      arguments = { message: { key: 'val' } }
      with_task_containing('tasks_test_hash', contents, 'environment', '.ps1') do |task|
        expect(
          winrm.run_task(target, task, arguments).value
        ).to eq('key' => 'val')
      end
    end

    it "can run a task with Sensitive params via environment", winrm: true do
      contents = <<PS
Write-Host "$env:PT_sensitive_string"
Write-Host "$env:PT_sensitive_array"
Write-Host "$env:PT_sensitive_hash"
PS
      deep_hash = { 'k' => Sensitive.new('v') }
      arguments = { 'sensitive_string' => Sensitive.new('$ecret!'),
                    'sensitive_array'  => Sensitive.new([1, 2, Sensitive.new(3)]),
                    'sensitive_hash'   => Sensitive.new(deep_hash) }
      with_task_containing('tasks_test_sensitive', contents, 'both', '.ps1') do |task|
        expect(winrm.run_task(target, task, arguments).message).to eq(<<QUOTED)
$ecret!\r
[1,2,3]\r
{"k":"v"}\r
QUOTED
      end
    end

    it "can run a task with Sensitive params via stdin", winrm: true do
      contents = <<PS
$line = [Console]::In.ReadLine()
Write-Host $line
PS
      arguments = { 'sensitive_string' => Sensitive.new('$ecret!') }
      with_task_containing('tasks_test_sensitive', contents, 'stdin', '.ps1') do |task|
        expect(winrm.run_task(target, task, arguments).value)
          .to eq("sensitive_string" => "$ecret!")
      end
    end

    it "defaults to powershell input method when executing .ps1", winrm: true do
      contents = <<PS
param ($message_one, $message_two)
Write-Host "$message_one $message_two"
PS
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_task_containing('tasks-test-both-winrm', contents, nil, '.ps1') do |task|
        expect(
          winrm.run_task(target, task, arguments).message
        ).to eq("Hello from task Goodbye\r\n")
      end
    end

    context "when implementations are provided", winrm: true do
      let(:contents) { 'Write-Host "$env:PT_message_one $env:PT_message_two"' }
      let(:arguments) { { message_one: 'Hello from task', message_two: 'Goodbye' } }

      it "runs a task requires 'shell'" do
        with_task_containing('tasks_test', contents, 'environment', '.ps1') do |task|
          impls = task.implementations.map { |impl| impl.merge('requirements' => ['powershell']) }
          expect(task).to receive(:implementations).and_return(impls)
          expect(winrm.run_task(target, task, arguments).message.chomp)
            .to eq('Hello from task Goodbye')
        end
      end

      it "errors when a task only requires an unsupported requirement" do
        with_task_containing('tasks_test', contents, 'environment', '.ps1') do |task|
          impls = task.implementations.map { |impl| impl.merge('requirements' => ['shell']) }
          expect(task).to receive(:implementations).and_return(impls)
          expect {
            winrm.run_task(target, task, arguments)
          }.to raise_error("No suitable implementation of #{task.name} for #{target.name}")
        end
      end

      it "errors when a task only requires an unknown requirement" do
        with_task_containing('tasks_test', contents, 'environment', '.ps1') do |task|
          impls = task.implementations.map { |impl| impl.merge('requirements' => ['foobar']) }
          expect(task).to receive(:implementations).and_return(impls)
          expect {
            winrm.run_task(target, task, arguments)
          }.to raise_error("No suitable implementation of #{task.name} for #{target.name}")
        end
      end
    end

    describe "when determining result" do
      it "fails to run a .pp task without Puppet agent installed", winrm: true do
        with_task_containing('task-pp-winrm', "notice('hi')", 'stdin', '.pp') do |task|
          result = winrm.run_task(target, task, {})
          expect(result).to_not be_success
        end
      end

      it "fails when a PowerShell script exits with a code", winrm: true do
        contents = <<-PS
        exit 42
        PS

        with_tempfile_containing('script-test-winrm', contents, '.ps1') do |file|
          result = winrm.run_script(target, file.path, [])
          expect(result).to_not be_success
          expect(result['exit_code']).to eq(42)
        end
      end

      context "fails for PowerShell terminating errors: " do
        it "exception thrown", winrm: true do
          contents = <<-PS
          throw "My Error"
          PS

          with_tempfile_containing('script-test-winrm', contents, '.ps1') do |file|
            result = winrm.run_script(target, file.path, [])
            expect(result).to_not be_success
            expect(result['exit_code']).to eq(1)
          end
        end

        it "Write-Error and $ErrorActionPreference Stop", winrm: true do
          contents = <<-PS
          $ErrorActionPreference = 'Stop'
          Write-Error "error stream addition"
          PS

          with_tempfile_containing('script-test-winrm', contents, '.ps1') do |file|
            result = winrm.run_script(target, file.path, [])
            expect(result).to_not be_success
          end
        end

        it "ParserError Code (IncompleteParseException)", winrm: true do
          contents = '{'

          with_tempfile_containing('script-test-winrm', contents, '.ps1') do |file|
            result = winrm.run_script(target, file.path, [])
            expect(result).to_not be_success
          end
        end

        it "ParserError Code", winrm: true do
          contents = <<-PS
          if (1 -badop 2) { Write-Out 'hi' }
          PS

          with_tempfile_containing('script-test-winrm', contents, '.ps1') do |file|
            result = winrm.run_script(target, file.path, [])
            expect(result).to_not be_success
          end
        end

        it "Correct syntax bad command (CommandNotFoundException)", winrm: true do
          contents = <<-PS
          Foo-Bar
          PS

          with_tempfile_containing('script-test-winrm', contents, '.ps1') do |file|
            result = winrm.run_script(target, file.path, [])
            expect(result).to_not be_success
          end
        end
      end

      context "does not fail for PowerShell non-terminating errors:" do
        it "Write-Error with default $ErrorActionPreference", winrm: true do
          contents = <<-PS
          Write-Error "error stream addition"
          PS

          with_tempfile_containing('script-test-winrm', contents, '.ps1') do |file|
            result = winrm.run_script(target, file.path, [])
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

          with_tempfile_containing('script-test-winrm', contents, '.ps1') do |file|
            result = winrm.run_script(target, file.path, [])
            expect(result).to be_success
          end
        end
      end
    end

    describe "when tmpdir is specified", winrm: true do
      let(:tmpdir) { 'C:\mytmp' }
      let(:config) { mk_config(tmpdir: 'C:\mytmp', ssl: false, user: user, password: password) }

      it 'uploads scripts to the specified tmpdir' do
        contents = "Write-Host $PSScriptRoot"
        with_tempfile_containing('script-test-winrm', contents, '.ps1') do |file|
          expect(winrm.run_script(target, file.path, [])['stdout']).to match(/#{Regexp.escape(tmpdir)}/)
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
        expect_any_instance_of(Bolt::Transport::WinRM::Connection)
          .to receive(:execute_process)
          .with('powershell.exe',
                ['-NoProfile', '-NonInteractive', '-NoLogo',
                 '-ExecutionPolicy', 'Bypass', '-File', /^".*"$/],
                anything)
          .and_return(output)
        with_task_containing('task-ps1-winrm', contents, 'stdin', '.ps1') do |task|
          expect(
            winrm.run_task(target, task, {}).message
          ).to eq("42")
        end
      end

      it "can apply a ruby-based script", winrm: true do
        expect_any_instance_of(Bolt::Transport::WinRM::Connection)
          .to receive(:execute_process)
          .with('ruby.exe',
                ['-S', /^".*"$/])
          .and_return(output)
        with_tempfile_containing('script-rb-winrm', "puts 42", '.rb') do |file|
          expect(
            winrm.run_script(target, file.path, [])['stdout']
          ).to eq("42")
        end
      end

      it "can apply a ruby-based task", winrm: true do
        expect_any_instance_of(Bolt::Transport::WinRM::Connection)
          .to receive(:execute_process)
          .with('ruby.exe',
                ['-S', /^".*"$/],
                anything)
          .and_return(output)
        with_task_containing('task-rb-winrm', "puts 42", 'stdin', '.rb') do |task|
          expect(
            winrm.run_task(target, task, {}).message
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

        expect_any_instance_of(Bolt::Transport::WinRM::Connection)
          .to receive(:execute_process)
          .with('puppet.bat',
                ['apply', /^".*"$/])
          .and_return(output)
        contents = "notice('hi')"
        with_tempfile_containing('script-pp-winrm', contents, '.pp') do |file|
          expect(
            winrm.run_script(target, file.path, [])['stdout']
          ).to eq(stdout)
        end
      end

      it "can apply a puppet manifest for a '.pp' task", winrm: true do
        expect_any_instance_of(Bolt::Transport::WinRM::Connection)
          .to receive(:execute_process)
          .with('puppet.bat',
                ['apply', /^".*"$/],
                anything)
          .and_return(output)
        with_task_containing('task-pp-winrm', "notice('hi')", 'stdin', '.pp') do |task|
          expect(
            winrm.run_task(target, task, {}).message
          ).to eq("42")
        end
      end

      it "does not apply an arbitrary script", winrm: true do
        allow_any_instance_of(Bolt::Transport::WinRM::Connection)
          .to receive(:execute_process)
          .with('cmd.exe',
                ['/c', /^".*"$/])
          .and_return(output)
        with_tempfile_containing('script-py-winrm', 'print(42)', '.py') do |file|
          expect {
            winrm.run_script(target, file.path, []).value
          }.to raise_error(Bolt::Node::FileError,
                           "File extension .py is not enabled, to run it please add to 'winrm: extensions'")
        end
      end

      it "does not apply an arbitrary script as a task", winrm: true do
        allow_any_instance_of(Bolt::Transport::WinRM::Connection)
          .to receive(:execute_process)
          .with('cmd.exe',
                ['/c', /^".*"$/],
                anything)
          .and_return(output)
        with_task_containing('task-py-winrm', 'print(42)', 'stdin', '.py') do |task|
          expect {
            winrm.run_task(target, task, {}).value
          }.to raise_error(Bolt::Node::FileError,
                           "File extension .py is not enabled, to run it please add to 'winrm: extensions'")
        end
      end

      context "with extensions specified" do
        let(:config) { mk_config(ssl: false, extensions: 'py', user: user, password: password) }

        it "can apply an arbitrary script", winrm: true do
          expect_any_instance_of(Bolt::Transport::WinRM::Connection)
            .to receive(:execute_process)
            .with('cmd.exe',
                  ['/c', /^".*"$/])
            .and_return(output)
          with_tempfile_containing('script-py-winrm', 'print(42)', '.py') do |file|
            expect(
              winrm.run_script(target, file.path, [])['stdout']
            ).to eq('42')
          end
        end

        it "can apply an arbitrary script as a task", winrm: true do
          expect_any_instance_of(Bolt::Transport::WinRM::Connection)
            .to receive(:execute_process)
            .with('cmd.exe',
                  ['/c', /^".*"$/],
                  anything)
            .and_return(output)
          with_task_containing('task-py-winrm', 'print(42)', 'stdin', '.py') do |task|
            expect(
              winrm.run_task(target, task, {}).message
            ).to eq('42')
          end
        end
      end

      it "returns a friendly stderr msg with puppet.bat missing", winrm: true do
        with_task_containing('task-pp-winrm', "notice('hi')", 'stdin', '.pp') do |task|
          result = winrm.run_task(target, task, {})
          stderr = result.error_hash['msg']
          expect(stderr).to match(/^The term 'puppet.bat' is not recognized as the name of a cmdlet/)
        end
      end
    end
  end
end
