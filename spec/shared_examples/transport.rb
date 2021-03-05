# frozen_string_literal: true

require 'bolt_spec/config'
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
  # The docker transport doesn't run commands in a shell by default so commands
  # that interpolate variables won't work. For other transports, on the other
  # hand, that's exactly the behavior we want to ensure.
  env_command = if target.protocol == 'docker'
                  "printenv BOLT_TEST_VAR"
                else
                  'echo $BOLT_TEST_VAR'
                end

  {
    stdout_command: ['echo hello', /^hello$/],
    stderr_command: ['ssh -V', /OpenSSH/],
    destination_dir: '/tmp',
    # Grep exits non-zero? This works locally, I'm not sure why it doesn't in CI
    pipe_command: ["service --status-all | sed -n \"/rsy/ p\"", /rsync/],
    supported_req: 'shell',
    extension: '.sh',
    unsupported_req: 'powershell',
    cat_cmd: 'cat',
    rm_cmd: 'rm -rf',
    ls_cmd: 'ls',
    env_command: env_command,
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
    stdout_command: ['echo hello', /^hello\r$/],
    stderr_command: ['echo oops 1>&2', /oops/],
    pipe_command: ["Get-Service | Where-Object {$_.Name -like \"*net*\"}", /Netman/],
    destination_dir: 'C:/mytmp',
    supported_req: 'powershell',
    extension: '.ps1',
    unsupported_req: 'shell',
    cat_cmd: 'cat',
    rm_cmd: 'rm -Recurse -Force',
    ls_cmd: 'ls -Name',
    env_command: 'Write-Output ${env:BOLT_TEST_VAR}',
    env_task: "Write-Output \"${env:PT_message_one}\n${env:PT_message_two}\"",
    stdin_task: "$line = [Console]::In.ReadLine()\nWrite-Output \"$line\"",
    find_task: 'Get-ChildItem -Path $env:PT__installdir -Recurse -File | % { Write-Host $_.Length $_.FullName  }',
    identity_script: "echo $PSScriptRoot",
    echo_script: "$args | ForEach-Object { Write-Output $_ }"
  }
end

def make_target
  inventory.get_target(host_and_port)
end

def set_config(target, config)
  merged = target.options.merge(config).to_h
  target.inventory_target.set_config(transport.to_s, merged)
end

# Shared examples for Transports.
#
# Requires the following variables
# - target: a valid Target
# - runner: instantiation of the Transport
# - os_context: posix_context above
# - transport_conf: a hash that can be overridden to specify the 'tmpdir' transport option
shared_examples 'transport api' do
  include BoltSpec::Config
  include BoltSpec::Files
  include BoltSpec::Sensitive
  include BoltSpec::Task

  before(:all) do
    Dir.mkdir('C:\mytmp') if Bolt::Util.windows?
  end

  after(:all) do
    Dir.rmdir('C:\mytmp') if Bolt::Util.windows?
  end

  context 'run_command' do
    it "executes a command on a host" do
      command, expected = os_context[:stdout_command]
      result = runner.run_command(target, command)
      expect(result.value['stdout']).to match(expected)
      expect(result.action).to eq('command')
      expect(result.object).to eq(command)
    end

    it "captures stderr from a host" do
      command, expected = os_context[:stderr_command]
      expect(runner.run_command(target, command).value['stderr']).to match(expected)
    end

    it "can execute a command containing quotes" do
      result = runner.run_command(target, "echo 'hello \" world'").value
      expect(result['exit_code']).to eq(0)
      expect(result['stderr']).to eq('')
      expect(result['stdout']).to match(/hello " world/)
    end

    it "can return a non-zero exit status" do
      command = if target.protocol == 'docker'
                  # explicitly launch bash for Docker transport because Docker doesn't have
                  # a default shell when you perform: docker exec
                  "/bin/bash -c 'exit 2'"
                else
                  "exit 2"
                end
      result = runner.run_command(target, command, catch_errors: true).value
      expect(result['exit_code']).to eq(2)
    end

    it "sets environment variables if specified" do
      result = runner.run_command(target, os_context[:env_command], env_vars: { 'BOLT_TEST_VAR' => 'hello world' })
      expect(result['stdout']).to include('hello world')
    end
  end

  context 'download_file' do
    let(:contents)    { SecureRandom.uuid }
    let(:remote_path) { File.join(os_context[:destination_dir], 'download-test') }
    let(:remote_dir)  { File.join(remote_path, dir) }
    let(:basename)    { 'download-test' }
    let(:dir)         { 'dir' }
    let(:subdir)      { 'subdir' }
    let(:file)        { 'file.txt' }
    let(:subfile)     { 'subfile.txt' }

    it 'can download a file from a host' do
      with_tempfile_containing(basename, contents) do |file|
        runner.upload(target, file.path, remote_path)
      end

      Dir.mktmpdir(nil, Dir.pwd) do |destination|
        result = runner.download(target, remote_path, destination)

        expect(result.message).to eq("Downloaded '#{target.host}:#{remote_path}' to '#{destination}'")
        expect(result.action).to eq('download')
        expect(result.object).to eq(remote_path)
        expect(result['path']).to eq(File.join(destination, basename))
        expect(File.exist?(result['path'])).to eq(true)
        expect(File.read(result['path'])).to match(/#{contents}/)
      end
    ensure
      runner.run_command(target, "#{os_context[:rm_cmd]} #{remote_path}")
    end

    it 'can download a directory from a host' do
      Dir.mktmpdir(nil, Dir.pwd) do |tmp|
        dir_path = File.join(tmp, dir)
        subdir_path = File.join(dir_path, subdir)

        Dir.mkdir(dir_path)
        Dir.mkdir(subdir_path)
        File.write(File.join(dir_path, file), 'foo')
        File.write(File.join(subdir_path, subfile), 'bar')

        runner.upload(target, tmp, remote_path)
      end

      Dir.mktmpdir(nil, Dir.pwd) do |destination|
        result = runner.download(target, remote_dir, destination)

        expect(result.message).to eq("Downloaded '#{target.host}:#{remote_dir}' to '#{destination}'")
        expect(result.action).to eq('download')
        expect(result.object).to eq(remote_dir)
        expect(result['path']).to eq(File.join(destination, dir))
        expect(Dir.exist?(result['path'])).to eq(true)
        expect(Dir.children(result['path'])).to match_array([subdir, file])
        expect(Dir.children(File.join(result['path'], subdir))).to match_array([subfile])
      end
    ensure
      runner.run_command(target, "#{os_context[:rm_cmd]} #{remote_path}")
    end
  end

  context 'upload_file' do
    it "can upload a file to a host" do
      contents = "kljhdfg"
      remote_path = File.join(os_context[:destination_dir], 'upload-test')
      with_tempfile_containing('upload-test', contents) do |file|
        result = runner.upload(target, file.path, remote_path)
        expect(result.message).to eq("Uploaded '#{file.path}' to '#{target.host}:#{remote_path}'")
        expect(result.action).to eq('upload')
        expect(result.object).to eq(file.path)

        expect(
          runner.run_command(target, "#{os_context[:cat_cmd]} #{remote_path}").value['stdout'].chomp
        ).to eq(contents)

        runner.run_command(target, "#{os_context[:rm_cmd]} #{remote_path}")
      end
    end

    it "can upload a file to a directory on a host" do
      contents = "kljhdfg"
      with_tempfile_containing('upload-test', contents) do |file|
        remote_path = File.join(os_context[:destination_dir], File.basename(file.path))
        result = runner.upload(target, file.path, os_context[:destination_dir])
        expect(result.message).to eq("Uploaded '#{file.path}' to '#{target.host}:#{os_context[:destination_dir]}'")
        expect(result.action).to eq('upload')
        expect(result.object).to eq(file.path)

        expect(
          runner.run_command(target, "#{os_context[:cat_cmd]} #{remote_path}").value['stdout'].chomp
        ).to eq(contents)

        runner.run_command(target, "#{os_context[:rm_cmd]} #{remote_path}")
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

        expect(
          runner.run_command(target, "#{os_context[:ls_cmd]} #{target_dir}")['stdout'].lines.map(&:chomp)
        ).to contain_exactly('content', 'subdir')

        expect(
          runner.run_command(target, "#{os_context[:ls_cmd]} #{File.join(target_dir, 'subdir')}")['stdout']
            .lines.map(&:chomp)
        ).to eq(%w[more])

        runner.run_command(target, "#{os_context[:rm_cmd]} #{target_dir}")
      end
    end
  end

  context 'run_script' do
    it "can run a script remotely" do
      with_tempfile_containing('script test', os_context[:echo_script], os_context[:extension]) do |file|
        result = runner.run_script(target, file.path, [])
        expect(result['stdout'].strip).to eq('')
        expect(result.action).to eq('script')
        expect(result.object).to eq(file.path)
      end
    end

    it "can run a script remotely with quoted arguments" do
      with_tempfile_containing('script-test-docker-quotes', os_context[:echo_script], os_context[:extension]) do |file|
        expected = <<~QUOTED
                     nospaces
                     with spaces
                     "double double"
                     'double single'
                     double "double" double
                     double 'single' double
                   QUOTED

        expect(
          runner.run_script(target,
                            file.path,
                            ['nospaces',
                             'with spaces',
                             "\"double double\"",
                             "'double single'",
                             "double \"double\" double",
                             "double 'single' double"])['stdout']
            .lines.map(&:chomp)
        ).to eq(expected.lines.map(&:chomp))
      end
    end

    it "can run a script with Sensitive arguments" do
      arguments = ['non-sensitive-arg',
                   make_sensitive('$ecret!')]
      with_tempfile_containing('sensitive_test', os_context[:echo_script], os_context[:extension]) do |file|
        expect(
          runner.run_script(target, file.path, arguments)['stdout'].lines.map(&:chomp)
        ).to eq(%w[non-sensitive-arg $ecret!])
      end
    end

    it "escapes unsafe shellwords in arguments" do
      with_tempfile_containing('script-test-docker-escape', os_context[:echo_script], os_context[:extension]) do |file|
        expect(
          runner.run_script(target,
                            file.path,
                            ['echo $HOME; cat /etc/passwd'])['stdout'].chomp
        ).to eq("echo $HOME; cat /etc/passwd")
      end
    end
  end

  context 'run_task' do
    it "can run a task" do
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_task_containing('tasks_test', os_context[:env_task], 'environment', os_context[:extension]) do |task|
        result = runner.run_task(target, task, arguments)
        expect(result.message.chomp).to eq("Hello from task\nGoodbye")
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
        expect(runner.run_task(target, task, arguments).message.lines.map(&:chomp)).to eq(<<~OUTPUT.lines.map(&:chomp))
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
        expect(runner.run_task(target, task, arguments).message.lines.map(&:chomp)).to eq(<<~SHELL.lines.map(&:chomp))
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
        expect(runner.run_task(target, task, arguments).message.chomp)
          .to eq("Hello from task\nGoodbye")
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
        files = files.each_with_object([]) { |file, acc| acc << file.gsub(/\\\\?/, "/") } if Bolt::Util.windows?

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
        files = files.each_with_object([]) { |file, acc| acc << file.gsub(/\\\\?/, "/") } if Bolt::Util.windows?

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
      hash = {
        'uri' => 'foo://user:pass@example.com/path/to?query=hey',
        'config' => {
          'transport' => 'remote',
          'remote' => {
            'run-on' => target.name,
            'type' => 'advice'
          }
        }
      }
      Bolt::Target.from_hash(hash, inventory)
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
        expect(result['_target']).to include('type' => 'advice')
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
        expect(result['_target']).to include('type' => 'advice')
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
    let(:tmpdir) { File.join(os_context[:destination_dir], 'mytmpdir') }

    it "errors when tmpdir doesn't exist" do
      skip "Windows will create the directory anyway" if Bolt::Util.windows?
      set_config(target, 'tmpdir' => tmpdir)

      with_tempfile_containing('script dir', 'dummy script', os_context[:extension]) do |file|
        expect {
          runner.run_script(target, file.path, [])
        }.to raise_error(Bolt::Node::FileError, /Could not make tmpdir.*#{Regexp.escape(tmpdir)}/)
      end
    end

    context 'with tmpdir' do
      around(:each) do |example|
        # This assumes that the thing running the tests is the
        # same platform as the thing we're running the task on
        use_windows = Bolt::Util.windows?
        if target.transport == "docker"
          # Only support linux containers with the docker transport
          use_windows = false
        end

        if use_windows
          mkdir = "powershell.exe new-item #{tmpdir} -itemtype directory"
          rmdir = "powershell.exe remove-item #{tmpdir} -Recurse -Force"
        else
          mkdir = "mkdir #{tmpdir}"
          rmdir = "#{os_context[:rm_cmd]} #{tmpdir}"
        end

        runner.run_command(target, mkdir)
        # Once the tmpdir is created the target can be configured to upload scripts to it
        set_config(target, 'tmpdir' => tmpdir)
        example.run
        # Required because the Local transport changes to the tmpdir before running commands
        set_config(target, 'tmpdir' => nil)
        runner.run_command(target, rmdir)
      end

      it 'uploads a script to the specified tmpdir' do
        with_tempfile_containing('script dir', os_context[:identity_script], os_context[:extension]) do |file|
          output = runner.run_script(target, file.path, [])['stdout']
          output = output.gsub(/\\\\?/, "/") if Bolt::Util.windows?
          expect(output).to match(/#{Regexp.escape(tmpdir)}/)
        end
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
    let(:transport_config) do
      {
        'host-key-check' => false,
        'sudo-password'  => password,
        'run-as'         => 'root',
        'user'           => user,
        'password'       => password
      }
    end

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

    it "can download a file as root" do
      contents = "download file test as root content"
      filename = 'test.txt'
      source   = "/root/#{filename}"

      expect(runner.run_command(target, "echo '#{contents}' > #{source}").ok?).to be
      expect(runner.run_command(target, "cat #{source}")['stdout']).to match(/#{contents}/)
      expect(runner.run_command(target, "stat -c %U #{source}")['stdout'].chomp).to eq('root')
      expect(runner.run_command(target, "stat -c %G #{source}")['stdout'].chomp).to eq('root')

      Dir.mktmpdir(nil, Dir.pwd) do |destination|
        expect(
          runner.download(target, source, destination).value
        ).to eq(
          '_output' => "Downloaded '#{target.host}:#{source}' to '#{destination}'",
          'path'    => File.expand_path(filename, destination)
        )

        expect(
          File.exist?(File.expand_path(filename, destination))
        ).to eq(true)

        expect(
          File.read(File.expand_path(filename, destination))
        ).to match(/#{contents}/)
      end

      runner.run_command(target, "rm #{source}")
    end

    context "with an incorrect password" do
      let(:transport_config) do
        {
          'host-key-check' => false,
          'sudo-password'  => 'nonsense',
          'run-as'         => 'root',
          'user'           => user,
          'password'       => password
        }
      end

      it "returns a failed result" do
        expect {
          runner.run_command(target, 'whoami')
        }.to raise_error(Bolt::Node::EscalateError,
                         "Sudo password for user #{user} not recognized on #{target.safe_name}")
      end
    end
  end

  context "using a custom run-as-command" do
    let(:transport_config) do
      {
        'host-key-check' => false,
        'sudo-password'  => password,
        'run-as'         => 'root',
        'user'           => user,
        'password'       => password,
        'run-as-command' => ['sudo', '-nkSEu']
      }
    end

    it "can fail to execute with sudo -n" do
      expect(runner.run_command(target, 'whoami')['stderr']).to match("sudo: a password is required")
    end
  end
end
