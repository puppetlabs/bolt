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
    destination_dir: 'C:/mytmp',
    supported_req: 'powershell',
    extension: '.ps1',
    unsupported_req: 'shell',
    cat_cmd: 'cat',
    rm_cmd: 'rm -rf',
    ls_cmd: 'ls',
    env_task: "Write-Output \"${env:PT_message_one}\n${env:PT_message_two}\"",
    stdin_task: "$line = [Console]::In.ReadLine()\nWrite-Output \"$line\"",
    find_task: 'Get-ChildItem -Path $env:PT__installdir -Recurse -File | % { Write-Host $_.Length $_.FullName  }',
    identity_script: "echo $PSScriptRoot",
    echo_script: "$args | ForEach-Object { Write-Output $_ }"
  }
end

# Shared examples for Transports.
#
# Requires the following variables
# - target: a valid Target
# - runner: instantiation of the Transport
# - os_context: posix_context above
# - transport_conf: a hash that can be overridden to specify the 'tmpdir' transport option
shared_examples 'transport api' do
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
      expect(result.type).to eq('command')
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
                  "/bin/bash -c 'exit 1'"
                else
                  "exit 1"
                end
      result = runner.run_command(target, command, '_catch_errors' => true).value
      expect(result['exit_code']).to eq(1)
    end
  end

  context 'upload_file' do
    it "can upload a file to a host" do
      contents = "kljhdfg"
      remote_path = File.join(os_context[:destination_dir], 'upload-test')
      with_tempfile_containing('upload-test', contents) do |file|
        result = runner.upload(target, file.path, remote_path)
        expect(result.message).to eq("Uploaded '#{file.path}' to '#{target.host}:#{remote_path}'")
        expect(result.type).to eq('upload')
        expect(result.object).to eq(file.path)

        expect(
          runner.run_command(target, "#{os_context[:cat_cmd]} #{remote_path}").value['stdout']
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

        target_dir = File.join(os_context[:destination_dir], "/directory-test")
        runner.upload(target, dir, target_dir)

        expect(
          runner.run_command(target, "#{os_context[:ls_cmd]} #{target_dir}")['stdout'].split("\n")
        ).to eq(%w[content subdir])

        expect(
          runner.run_command(target, "#{os_context[:ls_cmd]} #{File.join(target_dir, 'subdir')}")['stdout'].split("\n")
        ).to eq(%w[more])

        runner.run_command(target, "#{os_context[:rm_cmd]} #{target_dir}")
      end
    end
  end

  context 'run_script' do
    it "can run a script remotely" do
      with_tempfile_containing('script test', os_context[:echo_script]) do |file|
        result = runner.run_script(target, file.path, [])
        expect(result['stdout'].strip).to eq('')
        expect(result.type).to eq('script')
        expect(result.object).to eq(file.path)
      end
    end

    it "can run a script remotely with quoted arguments" do
      with_tempfile_containing('script-test-docker-quotes', os_context[:echo_script], os_context[:extension]) do |file|
        expect(
          runner.run_script(target,
                            file.path,
                            ['nospaces',
                             'with spaces',
                             "\"double double\"",
                             "'double single'",
                             '\'single single\'',
                             '"single double"',
                             "double \"double\" double",
                             "double 'single' double",
                             'single "double" single',
                             'single \'single\' single'])['stdout']
        ).to eq(<<QUOTED)
nospaces
with spaces
"double double"
'double single'
'single single'
"single double"
double "double" double
double 'single' double
single "double" single
single 'single' single
QUOTED
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
        task['metadata']['implementations'] = [{ 'name' => 'tasks_test', 'requirements' => reqs }]
        expect(runner.run_task(target, task, arguments).message)
          .to eq("Hello from task\nGoodbye\n")
      end
    end

    it "runs a task with the implementation's input method" do
      with_task_containing('tasks_test', contents, 'stdin', os_context[:extension]) do |task|
        reqs = [os_context[:supported_req]]
        task['metadata']['implementations'] = [{
          'name' => 'tasks_test', 'requirements' => reqs, 'input_method' => 'environment'
        }]
        expect(runner.run_task(target, task, arguments).message.chomp)
          .to eq("Hello from task\nGoodbye")
      end
    end

    it "errors when a task only requires an unsupported requirement" do
      with_task_containing('tasks_test', contents, 'environment', os_context[:extension]) do |task|
        reqs = [os_context[:unsupported_req]]
        task['metadata']['implementations'] = [{ 'name' => 'tasks_test', 'requirements' => reqs }]
        expect {
          runner.run_task(target, task, arguments)
        }.to raise_error(Bolt::NoImplementationError,
                         "No suitable implementation of #{task['name']} for #{target.name}")
      end
    end

    it "errors when a task only requires an unknown requirement" do
      with_task_containing('tasks_test', contents, 'environment', os_context[:extension]) do |task|
        task['metadata']['implementations'] = [{ 'name' => 'tasks_test', 'requirements' => ['foobar'] }]
        expect {
          runner.run_task(target, task, arguments)
        }.to raise_error("No suitable implementation of #{task['name']} for #{target.name}")
      end
    end
  end

  context "when files are provided" do
    let(:contents) { os_context[:find_task] }
    let(:arguments) { {} }

    it "puts files at _installdir" do
      with_task_containing('tasks_test', contents, 'environment', os_context[:extension]) do |task|
        task['metadata']['files'] = []
        expected_files = %w[files/foo files/bar/baz lib/puppet_x/file.rb tasks/init]
        expected_files.each do |file|
          task['metadata']['files'] << "tasks_test/#{file}"
          task['files'] << { 'name' => "tasks_test/#{file}", 'path' => task['files'][0]['path'] }
        end

        files = runner.run_task(target, task, arguments).message.split("\n")
        files = files.each_with_object([]) { |file, acc| acc << file.gsub(/\\\\?/, "/") } if Bolt::Util.windows?

        expected_files = ["tasks/#{File.basename(task['files'][0]['path'])}"] + expected_files
        expect(files.count).to eq(expected_files.count)
        files.sort.zip(expected_files.sort).each do |file, expected_file|
          expect(file).to match(%r{/tasks_test/#{expected_file}$})
        end
      end
    end

    it "includes files from the selected implementation" do
      with_task_containing('tasks_test', contents, 'environment', os_context[:extension]) do |task|
        task['metadata']['implementations'] = [
          { 'name' => 'tasks_test.alt', 'requirements' => ['foobar'], 'files' => ['tasks_test/files/no'] },
          { 'name' => 'tasks_test', 'requirements' => [], 'files' => ['tasks_test/files/yes'] }
        ]
        task['metadata']['files'] = ['other_mod/lib/puppet_x/']
        task_path = task['files'][0]['path']
        task['files'] << { 'name' => 'tasks_test/files/yes', 'path' => task_path }
        task['files'] << { 'name' => 'other_mod/lib/puppet_x/a.rb', 'path' => task_path }
        task['files'] << { 'name' => 'other_mod/lib/puppet_x/b.rb', 'path' => task_path }
        task['files'] << { 'name' => 'tasks_test/files/no', 'path' => task_path }

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
        task['metadata']['remote'] = true
        expect do
          runner.run_task(target, task, arguments)
        end.to raise_error("No suitable implementation of #{task['name']} for #{target.name}")
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
        task['metadata']['remote'] = true
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
        task['metadata']['implementations'] = [{ 'name' => 'tasks_test_stdin', 'remote' => true }]
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
                         "No suitable implementation of #{task['name']} for #{target.name}")
      end
    end

    it "errors when there is no remote implementation" do
      with_task_containing('tasks_test_stdin', os_context[:stdin_task], 'stdin') do |task|
        task['metadata']['implementations'] = [{ 'name' => 'tasks_test_stdin' }]
        expect {
          remote_runner.run_task(remote_target, task, {})
        }.to raise_error(Bolt::NoImplementationError,
                         "No suitable implementation of #{task['name']} for #{target.name}")
      end
    end
  end

  context 'when tmpdir is specified' do
    let(:tmpdir) { File.join(os_context[:destination_dir], 'mytempdir') }
    let(:transport_conf) { { 'tmpdir' => tmpdir } }

    it "errors when tmpdir doesn't exist" do
      with_tempfile_containing('script dir', 'dummy script') do |file|
        expect {
          runner.run_script(target, file.path, [])
        }.to raise_error(Bolt::Node::FileError, /Could not make tempdir.*#{Regexp.escape(tmpdir)}/)
      end
    end

    context 'with tmpdir' do
      around(:each) do |example|
        # Required because the Local transport changes to the tmpdir before running commands.
        safe_target = Bolt::Target.new(target.uri, target.options.reject { |opt| opt == 'tmpdir' })
        if Bolt::Util.windows?
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
          output = output.gsub(/\\\\?/, "/") if Bolt::Util.windows?
          expect(output).to match(/#{Regexp.escape(tmpdir)}/)
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
