# frozen_string_literal: true

require 'bolt_spec/files'
require 'bolt_spec/task'
require 'bolt_spec/sensitive'
require 'bolt/inventory'

def result_value(stdout = nil, stderr = nil, exit_code = 0)
  { 'stdout' => stdout || '',
    'stderr' => stderr || '',
    'exit_code' => exit_code }
end

def posix_context
  {
    stdout_command: ['echo hello', /^hello$/],
    stderr_command: ['ssh -V', /OpenSSH/],
    quotes_command: ["echo 'hello \" world'", /hello " world/],
    destination_dir: '/tmp',
    supported_req: 'shell',
    extension: '.sh',
    unsupported_req: 'powershell',
    cat_cmd: 'cat',
    rm_cmd: 'rm -rf',
    ls_cmd: 'ls',
    env_task: "#!/bin/sh\nprintenv PT_message_one\nprintenv PT_message_two",
    stdin_task: "#!/bin/sh\ncat",
    find_task: "#!/bin/sh\nfind ${PT__installdir} -type f -exec wc -c {} \\;",
    identity_script: "#!/bin/sh\n echo $0",
    echo_script: <<BASH
#!/bin/sh
for var in "$@"
do
    echo $var
done
BASH
  }
end

def windows_context
  {
    stdout_command: ['echo hello', /^hello$/],
    stderr_command: ['echo oops 1>&2', /oops/],
    quotes_command: ["echo 'hello \" world'", /hello " world/],
    destination_dir: 'C:/mytmp',
    supported_req: 'powershell',
    extension: '.ps1',
    unsupported_req: 'shell',
    cat_cmd: 'cat',
    rm_cmd: 'rm -rf', # TODO: This will not work on Windows. Not valid in powershell or cmd.exe
    ls_cmd: 'ls',
    env_task: "Write-Output \"${env:PT_message_one}\n${env:PT_message_two}\"",
    stdin_task: "$line = [Console]::In.ReadLine()\nWrite-Output \"$line\"",
    find_task: 'Get-ChildItem -Path $env:PT__installdir -Recurse -File | % { Write-Host $_.Length $_.FullName  }',
    identity_script: "echo $PSScriptRoot",
    echo_script: "$args | ForEach-Object { Write-Output $_ }"
  }
end

def windows_powershell_container_context
  # Unlike a linux based container, commands like echo are not binaries, they require a shell. Because Windows
  # Containers could be using either cmd.exe, powershell.exe, or even, pwsh.exe as the shell we can't assume anything
  # and instead need to be very specific about which shell we're going to use
  {
    command_prefix: 'powershell.exe -NoProfile -NonInteractive -NoLogo -ExecutionPolicy Bypass -Command',
    stdout_command: ['echo hello', /^hello$/],
    stderr_command: ['echo oops 1>&2', /oops/],
    # Due to some really weird double handling of quotes, we need three of them
    quotes_command: ["echo 'hello \"\"\" world'", /hello " world/],
    destination_dir: 'C:/mytmp',
    unsupported_req: 'foo-bar-buzz',
    supported_req: 'shell',
    extension: '.ps1',
    cat_cmd: '$content = Get-Content -Raw -Path',
    # Write-Host will append a newline so instead, use the Console Write method
    cat_cmd_suffix: '; [Console]::Write($content)',
    rm_cmd: 'Remove-Item -Force -Confirm:$false -Recurse -Path',
    ls_cmd: 'Get-ChildItem -Path',
    ls_cmd_suffix: ' | Sort-Object Name | % { Write-Output $_.Name }',
    env_task: "Write-Output \"${env:PT_message_one}\n${env:PT_message_two}\"",
    stdin_task: "$line = [Console]::In.ReadLine()\nWrite-Output \"$line\"",
    find_task: 'Get-ChildItem -Path $env:PT__installdir -Recurse -File | % { Write-Host $_.Length $_.FullName }',
    identity_script: "echo $PSScriptRoot",
    echo_script: "$args | ForEach-Object { Write-Output $_ }"
  }
end

def windows_cmd_container_context
  # Unlike a linux based container, commands like echo are not binaries, they require a shell. Because Windows
  # Containers could be using either cmd.exe, powershell.exe, or even, pwsh.exe as the shell we can't assume anything
  # and instead need to be very specific about which shell we're going to use
  {
    command_prefix: 'cmd /c',
    stdout_command: ['echo hello', /^hello$/],
    stderr_command: ['echo oops 1>&2', /oops/],
    # Single quotes are not used to wrap command line arguments in cmd.exe, only double quotes
    quotes_command: ["echo \"hello ' world\"", /hello ' world/],
    destination_dir: 'C:\\mytmp',
    unsupported_req: 'foo-bar-buzz',
    supported_req: 'shell',
    extension: '.bat',
    cat_cmd: 'type',
    rm_cmd: 'rd /s /q',
    rm_file_cmd: 'del /f /q',
    ls_cmd: 'dir /B', # Note that cmd.exe dir has a very different output to Linux ls
    env_task: "@ECHO OFF\r\n" \
              "IF DEFINED PT_message_one ECHO %PT_message_one%\r\n" \
              "IF DEFINED PT_message_two ECHO %PT_message_two%",
    stdin_task: "@ECHO OFF\r\nSET /P LINE=\r\nECHO %LINE%",
    # There is not way to emulate the Linux output expected so instead we just call the equivalent PowerShell
    # command using the EncodedCommand parameter
    find_task: "@ECHO OFF\npowershell.exe -NoProfile -NonInteractive -NoLogo -ExecutionPolicy Bypass -EncodedCommand " +
      Base64.strict_encode64(windows_powershell_container_context[:find_task].encode('UTF-16LE')),
    identity_script: "@ECHO OFF\r\necho %~dp0",

    echo_script: <<-BATCH
@ECHO OFF
:Loop
IF [[%1]]==[[]] GOTO :EOF
  ECHO %~1
SHIFT
GOTO Loop
BATCH
  }
end

def build_command(command, os_context)
  os_context[:command_prefix].nil? ? command : os_context[:command_prefix] + ' ' + command
end

def mk_config(conf)
  conf = Bolt::Util.walk_keys(conf, &:to_s)
  conf_object = Bolt::Config.new(Bolt::Boltdir.new('.'), transport.to_s => conf)
  conf_object.transport = transport.to_s
  conf_object
end

def make_target(target_: host_and_port, conf: config)
  Bolt::Target.new(target_, transport_conf).update_conf(conf.transport_conf)
end

# Shared examples for Transports.
#
# Requires the following variables
# - target: a valid Target
# - runner: instantiation of the Transport
# - os_context: posix_context above
# - default_transport_conf: a hash that should not be overridden and is required by the transport to test
# - transport_conf: a hash that can be overridden to specify the 'tmpdir' transport option
shared_examples 'transport api' do
  include BoltSpec::Files
  include BoltSpec::Sensitive
  include BoltSpec::Task

  before(:all) do
    if Bolt::Util.windows?
      FileUtils.rm_r('C:\mytmp', force: true) if Dir.exist?('C:\mytmp')
      Dir.mkdir('C:\mytmp')
    end
  end

  after(:all) do
    Dir.rmdir('C:\mytmp') if Bolt::Util.windows?
  end

  def platform_path(target, path)
    windows_target?(target) ? path.gsub('/', '\\') : path
  end

  def windows_target?(target)
    if target.transport == "docker"
      # This test is a little basic but it will do for testing
      return target.host =~ /windows/
    end
    # This assumes that the thing running the tests is the
    # same platform as the thing we're running the task on
    Bolt::Util.windows?
  end

  context 'run_command' do
    it "executes a command on a host" do
      command, expected = os_context[:stdout_command]
      command = build_command(command, os_context)
      result = runner.run_command(target, command)
      expect(result.value['stdout']).to match(expected)
      expect(result.action).to eq('command')
      expect(result.object).to eq(command)
    end

    it "captures stderr from a host" do
      command, expected = os_context[:stderr_command]
      command = build_command(command, os_context)
      expect(runner.run_command(target, command).value['stderr']).to match(expected)
    end

    it "can execute a command containing quotes" do
      command, expected = os_context[:quotes_command]
      command = build_command(command, os_context)
      result = runner.run_command(target, command)
      expect(result['exit_code']).to eq(0)
      expect(result['stderr']).to eq('')
      expect(result['stdout']).to match(expected)
    end

    it "can return a non-zero exit status" do
      command = if target.protocol == 'docker'
                  # explicitly launch a shell for Docker transport because Docker doesn't have
                  # a default shell when you perform: docker exec
                  target.host =~ /windows/ ? "cmd /c exit 1" : "/bin/bash -c 'exit 1'"
                else
                  "exit 1"
                end
      result = runner.run_command(target, command, catch_errors: true).value
      expect(result['exit_code']).to eq(1)
    end
  end

  context 'upload_file' do
    it "can upload a file to a host" do
      contents = "kljhdfg"
      remote_path = File.join(os_context[:destination_dir], 'upload-test')
      platform_remote_path = platform_path(target, remote_path)
      with_tempfile_containing('upload-test', contents) do |file|
        result = runner.upload(target, file.path, remote_path)
        expect(result.message).to eq("Uploaded '#{file.path}' to '#{target.host}:#{remote_path}'")
        expect(result.action).to eq('upload')
        expect(result.object).to eq(file.path)

        command = build_command("#{os_context[:cat_cmd]} #{platform_remote_path}#{os_context[:cat_cmd_suffix]}", os_context) # rubocop:disable Metrics/LineLength
        expect(
          runner.run_command(target, command).value['stdout']
        ).to eq(contents)

        if os_context[:rm_file_cmd].nil? # rubocop:disable Style/ConditionalAssignment
          command = build_command("#{os_context[:rm_cmd]} #{platform_remote_path}", os_context)
        else
          command = build_command("#{os_context[:rm_file_cmd]} #{platform_remote_path}", os_context)
        end
        runner.run_command(target, command)
      end
    end

    it "can upload a directory to a host" do
      Dir.mktmpdir do |dir|
        subdir = File.join(dir, 'subdir')
        File.write(File.join(dir, 'content'), 'hello world')
        Dir.mkdir(subdir)
        File.write(File.join(subdir, 'more'), 'lorem ipsum')

        target_dir = File.join(os_context[:destination_dir], "directory-test")
        runner.upload(target, dir, target_dir)
        platform_dir = platform_path(target, target_dir)
        expect(
          runner.run_command(target, build_command("#{os_context[:ls_cmd]} #{platform_dir}#{os_context[:ls_cmd_suffix]}", os_context))['stdout'].split("\n") # rubocop:disable Metrics/LineLength
        ).to eq(%w[content subdir])

        platform_subdir = platform_path(target, File.join(platform_dir, 'subdir'))
        expect(
          runner.run_command(target, build_command("#{os_context[:ls_cmd]} #{platform_subdir}#{os_context[:ls_cmd_suffix]}", os_context))['stdout'].split("\n") # rubocop:disable Metrics/LineLength
        ).to eq(%w[more])

        runner.run_command(target, build_command("#{os_context[:rm_cmd]} #{platform_dir}", os_context))
      end
    end
  end

  context 'run_script' do
    it "can run a script remotely" do
      with_tempfile_containing('script test', os_context[:echo_script], os_context[:extension]) do |file|
        file_path = platform_path(target, file.path)
        result = runner.run_script(target, file_path, [])
        expect(result['stdout'].strip).to eq('')
        expect(result.action).to eq('script')
        expect(result.object).to eq(file_path)
      end
    end

    it "can run a script remotely with quoted arguments" do
      quote_list = [
        'nospaces',
        'with spaces',
        "'double single'",
        "double 'single' double"
      ]

      unless os_context[:extension] == '.bat'
        # cmd.exe has no way of reliably passing in parameters with double quotes, particularly with the
        # many layers of abstractions within Bolt e.g. Ruby -> docker.exe -> cmd.exe or
        # Ruby -> over WinRM -> PowerShell -> cmd.exe
        # Therefore we don't test double quoted arguments for .bat files which are run by cmd.exe
        quote_list << "\"double double\""
        quote_list << "double \"double\" double"
      end
      expected_list = quote_list.join("\n")

      with_tempfile_containing('script-test-docker-quotes', os_context[:echo_script], os_context[:extension]) do |file|
        expect(
          runner.run_script(target, file.path, quote_list)['stdout'].chomp
        ).to eq(expected_list)
      end
    end

    it "can run a script with Sensitive arguments" do
      arguments = ['non-sensitive-arg',
                   make_sensitive('$ecret!')]
      with_tempfile_containing('sensitive_test', os_context[:echo_script], os_context[:extension]) do |file|
        expect(
          runner.run_script(target, file.path, arguments)['stdout']
        ).to eq("non-sensitive-arg\n$ecret!\n")
      end
    end

    it "escapes unsafe shellwords in arguments" do
      # TODO: Skip this for windows. Unsafe shellwords mean nothing on Win32
      with_tempfile_containing('script-test-docker-escape', os_context[:echo_script], os_context[:extension]) do |file|
        expect(
          runner.run_script(target,
                            file.path,
                            ['echo $HOME; cat /etc/passwd'])['stdout']
        ).to eq(<<~SHELLWORDS)
        echo $HOME; cat /etc/passwd
        SHELLWORDS
      end
    end
  end

  context 'run_task' do
    it "can run a task" do
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_task_containing('tasks_test', os_context[:env_task], 'environment', os_context[:extension]) do |task|
        result = runner.run_task(target, task, arguments)
        expect(result.message).to eq("Hello from task\nGoodbye\n")
        expect(result.object).to eq('tasks_test')
      end
    end

    it "can run a task passing input on stdin" do
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_task_containing('tasks_test_stdin', os_context[:stdin_task], 'stdin', os_context[:extension]) do |task|
        expect(runner.run_task(target, task, arguments).value)
          .to eq("message_one" => "Hello from task", "message_two" => "Goodbye")
      end
    end

    it "serializes hashes as json in environment input" do
      arguments = { message_one: { key: 'val' }, message_two: '' }
      with_task_containing('tasks_test_hash', os_context[:env_task], 'environment', os_context[:extension]) do |task|
        expect(runner.run_task(target, task, arguments).value)
          .to eq('key' => 'val')
      end
    end

    it "can run a task passing input on stdin and environment" do
      content = "#{os_context[:env_task]}\n#{os_context[:stdin_task]}"
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_task_containing('tasks-test-both', content, 'both', os_context[:extension]) do |task|
        expect(runner.run_task(target, task, arguments).message.strip).to eq(<<~OUTPUT.strip)
        Hello from task
        Goodbye
        {"message_one":"Hello from task","message_two":"Goodbye"}
        OUTPUT
      end
    end

    it "can run a task with params containing quotes" do
      arguments = { message_one: "foo ' bar ' baz", message_two: '' }
      with_task_containing('tasks_test_quotes', os_context[:env_task], 'both', os_context[:extension]) do |task|
        expect(runner.run_task(target, task, arguments).message.strip).to eq("foo ' bar ' baz")
      end
    end

    it "can run a task with params containing variable references" do
      arguments = { message: "$PATH" }
      with_task_containing('tasks_test_var', os_context[:stdin_task], 'both', os_context[:extension]) do |task|
        expect(runner.run_task(target, task, arguments)['message']).to eq("$PATH")
      end
    end

    it "can run a task with Sensitive params via environment" do
      deep_hash = { 'k' => make_sensitive('v'), 'arr' => make_sensitive([1, 2, make_sensitive(3)]) }
      arguments = { 'message_one' => make_sensitive('$ecret!'),
                    'message_two' => make_sensitive(deep_hash) }
      with_task_containing('tasks_test_sensitive', os_context[:env_task], 'both', os_context[:extension]) do |task|
        expect(runner.run_task(target, task, arguments).message).to eq(<<~SHELL)
        $ecret!
        {"k":"v","arr":[1,2,3]}
        SHELL
      end
    end

    it "can run a task with Sensitive params via stdin" do
      arguments = { 'sensitive_string' => make_sensitive('$ecret!') }
      with_task_containing('tasks_test_sensitive', os_context[:stdin_task], 'stdin', os_context[:extension]) do |task|
        expect(runner.run_task(target, task, arguments).value)
          .to eq("sensitive_string" => "$ecret!")
      end
    end
  end

  context "when implementations are provided" do
    let(:contents) { os_context[:env_task] }
    let(:arguments) { { message_one: 'Hello from task', message_two: 'Goodbye' } }

    it "runs a task requires 'shell'" do
      with_task_containing('tasks_test', contents, 'environment', os_context[:extension]) do |task|
        reqs = [os_context[:supported_req]]
        task.metadata['implementations'] = [{ 'name' => 'tasks_test', 'requirements' => reqs }]
        expect(runner.run_task(target, task, arguments).message)
          .to eq("Hello from task\nGoodbye\n")
      end
    end

    it "runs a task with the implementation's input method" do
      with_task_containing('tasks_test', contents, 'stdin', os_context[:extension]) do |task|
        reqs = [os_context[:supported_req]]
        task.metadata['implementations'] = [{
          'name' => 'tasks_test', 'requirements' => reqs, 'input_method' => 'environment'
        }]
        expect(runner.run_task(target, task, arguments).message.chomp)
          .to eq("Hello from task\nGoodbye")
      end
    end

    it "errors when a task only requires an unsupported requirement" do
      with_task_containing('tasks_test', contents, 'environment', os_context[:extension]) do |task|
        reqs = [os_context[:unsupported_req]]
        task.metadata['implementations'] = [{ 'name' => 'tasks_test', 'requirements' => reqs }]
        expect {
          runner.run_task(target, task, arguments)
        }.to raise_error(Bolt::NoImplementationError,
                         "No suitable implementation of #{task.name} for #{target.name}")
      end
    end

    it "errors when a task only requires an unknown requirement" do
      with_task_containing('tasks_test', contents, 'environment', os_context[:extension]) do |task|
        task.metadata['implementations'] = [{ 'name' => 'tasks_test', 'requirements' => ['foobar'] }]
        expect {
          runner.run_task(target, task, arguments)
        }.to raise_error("No suitable implementation of #{task.name} for #{target.name}")
      end
    end
  end

  context "when files are provided" do
    let(:contents) { os_context[:find_task] }
    let(:arguments) { {} }

    it "puts files at _installdir" do
      with_task_containing('tasks_test', contents, 'environment', os_context[:extension]) do |task|
        task.metadata['files'] = []
        expected_files = %w[files/foo files/bar/baz lib/puppet_x/file.rb tasks/init]
        expected_files.each do |file|
          task.metadata['files'] << "tasks_test/#{file}"
          task.files << { 'name' => "tasks_test/#{file}", 'path' => task.files[0]['path'] }
        end

        files = runner.run_task(target, task, arguments).message.split("\n")
        files = files.each_with_object([]) { |file, acc| acc << file.gsub(/\\\\?/, "/") } if windows_target?(target)

        expected_files = ["tasks/#{File.basename(task.files[0]['path'])}"] + expected_files
        expect(files.count).to eq(expected_files.count)
        files.sort.zip(expected_files.sort).each do |file, expected_file|
          expect(file).to match(%r{/tasks_test/#{expected_file}$})
        end
      end
    end

    it "includes files from the selected implementation" do
      with_task_containing('tasks_test', contents, 'environment', os_context[:extension]) do |task|
        task.metadata['implementations'] = [
          { 'name' => 'tasks_test.alt', 'requirements' => ['foobar'], 'files' => ['tasks_test/files/no'] },
          { 'name' => 'tasks_test', 'requirements' => [], 'files' => ['tasks_test/files/yes'] }
        ]
        task.metadata['files'] = ['other_mod/lib/puppet_x/']
        task_path = task.files[0]['path']
        task.files << { 'name' => 'tasks_test/files/yes', 'path' => task_path }
        task.files << { 'name' => 'other_mod/lib/puppet_x/a.rb', 'path' => task_path }
        task.files << { 'name' => 'other_mod/lib/puppet_x/b.rb', 'path' => task_path }
        task.files << { 'name' => 'tasks_test/files/no', 'path' => task_path }

        files = runner.run_task(target, task, arguments).message.split("\n").sort
        files = files.each_with_object([]) { |file, acc| acc << file.gsub(/\\\\?/, "/") } if windows_target?(target)

        expect(files.count).to eq(4)
        expect(files[0]).to match(%r{#{contents.size} [^ ]+/other_mod/lib/puppet_x/a.rb$})
        expect(files[1]).to match(%r{#{contents.size} [^ ]+/other_mod/lib/puppet_x/b.rb$})
        expect(files[2]).to match(%r{#{contents.size} [^ ]+/tasks_test/files/yes$})
        expect(files[3]).to match(%r{#{contents.size} [^ ]+/tasks_test/tasks/#{File.basename(task_path)}$})
      end
    end
  end

  context 'with a remote task' do
    it 'fails to run' do
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_task_containing('tasks_test_stdin', os_context[:stdin_task], 'stdin', os_context[:extension]) do |task|
        task.metadata['remote'] = true
        expect do
          runner.run_task(target, task, arguments)
        end.to raise_error("No suitable implementation of #{task.name} for #{target.name}")
      end
    end
  end

  context 'when used by the remote transport' do
    let(:remote_target) do
      # TODO: remove the config here. it is a workaround for BOLT-943
      inventory = Bolt::Inventory.new('config' => { transport.to_s => target.options })
      inventory.add_to_group([target], 'all')
      remote_target = Bolt::Target.new('foo://user:pass@example.com/path/to?query=hey',
                                       'run-on' => target.name, 'type' => 'adevice')
      remote_target.inventory = inventory
      remote_target
    end

    let(:remote_runner) do
      executor = Bolt::Executor.new
      executor.transports[transport.to_s] = Concurrent::Delay.new { runner }
      executor.transports['remote'].value
    end

    it 'passes the correct _target' do
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_task_containing('tasks_test_stdin', os_context[:stdin_task], 'stdin', os_context[:extension]) do |task|
        task.metadata['remote'] = true
        result = remote_runner.run_task(remote_target, task, arguments).value
        expect(result).to include('message_one' => 'Hello from task')
        expect(result['_target']).to include("name" => "foo://user:pass@example.com/path/to?query=hey")
        expect(result['_target']).to include('type' => 'adevice')
        expect(result['_target']).to include('host' => 'example.com')
      end
    end

    it 'runs when there is a remote implementation' do
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_task_containing('tasks_test_stdin', os_context[:stdin_task], 'stdin', os_context[:extension]) do |task|
        task.metadata['implementations'] = [{ 'name' => 'tasks_test_stdin', 'remote' => true }]
        result = remote_runner.run_task(remote_target, task, arguments).value
        expect(result).to include('message_one' => 'Hello from task')
        expect(result['_target']).to include("name" => "foo://user:pass@example.com/path/to?query=hey")
        expect(result['_target']).to include('type' => 'adevice')
        expect(result['_target']).to include('host' => 'example.com')
      end
    end

    it "errors when the task is not remote" do
      with_task_containing('tasks_test_stdin', os_context[:stdin_task], 'stdin') do |task|
        expect {
          remote_runner.run_task(remote_target, task, {})
        }.to raise_error(Bolt::NoImplementationError,
                         "No suitable implementation of #{task.name} for #{target.name}")
      end
    end

    it "errors when there is no remote implementation" do
      with_task_containing('tasks_test_stdin', os_context[:stdin_task], 'stdin') do |task|
        task.metadata['implementations'] = [{ 'name' => 'tasks_test_stdin' }]
        expect {
          remote_runner.run_task(remote_target, task, {})
        }.to raise_error(Bolt::NoImplementationError,
                         "No suitable implementation of #{task.name} for #{target.name}")
      end
    end
  end

  context 'when tmpdir is specified' do
    let(:tmpdir) { File.join(os_context[:destination_dir], 'mytempdir') }
    let(:transport_conf) { default_transport_conf.merge('tmpdir' => tmpdir) }

    it "errors when tmpdir doesn't exist" do
      with_tempfile_containing('script dir', os_context[:stdout_command][0], os_context[:extension]) do |file|
        if target.transport == 'docker'
          # The docker transport error message will be platform specific due to the use of cmd.exe in Windows containers
          platform_tmpdir = platform_path(target, tmpdir)
        else
          # Whereas on all other transports, the path is normalised
          platform_tmpdir = tmpdir
        end
        expect {
          runner.run_script(target, file.path, [])
        }.to raise_error(Bolt::Node::FileError, /Could not make tempdir.*#{Regexp.escape(platform_tmpdir)}/)
      end
    end

    context 'with tmpdir' do
      around(:each) do |example|
        # Required because the Local transport changes to the tmpdir before running commands.
        safe_target = Bolt::Target.new(target.uri, target.options.reject { |opt| opt == 'tmpdir' })

        if windows_target?(target)
          mkdir = "powershell.exe new-item #{tmpdir} -itemtype directory"
          rmdir = "powershell.exe remove-item #{tmpdir} -Recurse -Force"
        else
          mkdir = "mkdir #{tmpdir}"
          rmdir = "#{os_context[:rm_cmd]} #{tmpdir}"
        end
        runner.run_command(safe_target, mkdir)
        example.run
        runner.run_command(safe_target, rmdir)
      end

      it 'uploads a script to the specified tmpdir' do
        with_tempfile_containing('script dir', os_context[:identity_script], os_context[:extension]) do |file|
          output = runner.run_script(target, file.path, [])['stdout']
          expect(output).to match(/#{Regexp.escape(platform_path(target, tmpdir))}/)
        end
      end
    end
  end
end

# Shared failure tests for Transports
#
# Requires uploading files and making tempdir to be stubbed to throw Bolt::Node::FileError.
shared_examples 'transport failures' do
  context "when it can't upload a file" do
    it 'returns an error result for upload' do
      with_tempfile_containing('upload-test', 'dummy file') do |file|
        expect {
          runner.upload(target, file.path, "/upload-test")
        }.to raise_error(Bolt::Node::FileError)
      end
    end

    it 'returns an error result for run_script' do
      with_tempfile_containing('script test', 'dummy script') do |file|
        expect {
          runner.run_script(target, file.path, [])
        }.to raise_error(Bolt::Node::FileError)
      end
    end

    it 'returns an error result for run_task' do
      with_task_containing('tasks_test', 'dummy task', 'environment') do |task|
        expect {
          runner.run_task(target, task, {})
        }.to raise_error(Bolt::Node::FileError)
      end
    end
  end

  context "when it can't create a tempfile" do
    it 'errors when it tries to run a script' do
      with_tempfile_containing('script test', 'dummy script') do |file|
        expect {
          runner.run_script(target, file.path, []).error_hash['msg']
        }.to raise_error(Bolt::Node::FileError)
      end
    end

    it "errors when it tries to run a task" do
      with_task_containing('tasks_test', 'dummy task', 'environment') do |task|
        expect {
          runner.run_task(target, task, {})
        }.to raise_error(Bolt::Node::FileError)
      end
    end
  end
end

# Shared run_as and sudo tests
#
# Requires the following variables
# - target: a valid Target
# - runner: instantiation of the Transport
# - host_and_port: host and port to connect to
# - user: the default user
# - password: the default user password
# - safe_name: expected target safe_name
shared_examples 'with sudo', sudo: true do
  context "with sudo" do
    let(:config) {
      mk_config('host-key-check' => false, 'sudo-password' => password, 'run-as' => 'root',
                user: user, password: password)
    }
    let(:target) { make_target }

    it "can execute a command" do
      expect(runner.run_command(target, 'whoami')['stdout']).to eq("root\n")
    end

    it "catches stderr from a command" do
      command, expected = os_context[:stderr_command]
      expect(runner.run_command(target, command).value['stderr']).to match(expected)
    end

    it "can run a task passing input on stdin" do
      contents = "#!/bin/sh\ngrep 'message_one'"
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_task_containing('tasks_test_stdin', contents, 'stdin') do |task|
        expect(runner.run_task(target, task, arguments).value)
          .to eq("message_one" => "Hello from task", "message_two" => "Goodbye")
      end
    end

    it "can run a task passing input with environment vars" do
      contents = "#!/bin/sh\necho -n ${PT_message_one} then ${PT_message_two}"
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_task_containing('tasks_test', contents, 'environment') do |task|
        expect(runner.run_task(target, task, arguments).message)
          .to eq('Hello from task then Goodbye')
      end
    end

    it "can run a task with params containing variable references" do
      contents = <<SHELL
#!/bin/sh
cat
SHELL

      arguments = { message: "$PATH" }
      with_task_containing('tasks_test_var', contents, 'both') do |task|
        expect(runner.run_task(target, task, arguments)['message']).to eq("$PATH")
      end
    end

    it "can upload a file as root" do
      contents = "upload file test as root content"
      dest = '/tmp/root-file-upload-test'
      with_tempfile_containing('tasks test upload as root', contents) do |file|
        expect(runner.upload(target, file.path, dest).message).to match(/Uploaded/)
        expect(runner.run_command(target, "cat #{dest}")['stdout']).to eq(contents)
        expect(runner.run_command(target, "stat -c %U #{dest}")['stdout'].chomp).to eq('root')
        expect(runner.run_command(target, "stat -c %G #{dest}")['stdout'].chomp).to eq('root')
      end

      runner.run_command(target, "rm #{dest}", sudoable: true, run_as: 'root')
    end

    context "with an incorrect password" do
      let(:config) {
        mk_config('host-key-check' => false, 'sudo-password' => 'nonsense', 'run-as' => 'root',
                  user: user, password: password)
      }
      let(:target) { make_target }

      it "returns a failed result" do
        expect {
          runner.run_command(target, 'whoami')
        }.to raise_error(Bolt::Node::EscalateError,
                         "Sudo password for user #{user} not recognized on #{safe_name}")
      end
    end

    context "with no password" do
      let(:config) { mk_config('host-key-check' => false, 'run-as' => 'root', user: user, password: password) }
      let(:target) { make_target }

      it "returns a failed result" do
        expect {
          runner.run_command(target, 'whoami')
        }.to raise_error(Bolt::Node::EscalateError,
                         "Sudo password for user #{user} was not provided for #{safe_name}")
      end
    end
  end

  context "using a custom run-as-command" do
    let(:config) {
      mk_config('host-key-check' => false, 'sudo-password' => password, 'run-as' => 'root',
                user: user, password: password,
                'run-as-command' => ["sudo", "-nkSEu"])
    }
    let(:target) { make_target }

    it "can fail to execute with sudo -n" do
      expect(runner.run_command(target, 'whoami')['stderr']).to match("sudo: a password is required")
    end
  end
end
