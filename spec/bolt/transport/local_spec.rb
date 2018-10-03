# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/errors'
require 'bolt_spec/files'
require 'bolt_spec/sensitive'
require 'bolt_spec/task'
require 'bolt/transport/local'
require 'bolt/config'

describe Bolt::Transport::Local do
  include BoltSpec::Errors
  include BoltSpec::Files
  include BoltSpec::Sensitive
  include BoltSpec::Task

  let(:local) { Bolt::Transport::Local.new }
  let(:echo_script) { <<BASH }
for var do
    echo $var
done
BASH

  let(:target) { Bolt::Target.new('local://localhost') }

  def result_value(stdout = nil, stderr = nil, exit_code = 0)
    { 'stdout' => stdout || '',
      'stderr' => stderr || '',
      'exit_code' => exit_code }
  end

  context "when executing", bash: true do
    it "executes a command" do
      expect(local.run_command(target, 'echo $HOME').value['stdout'].strip).to eq(ENV['HOME'])
    end

    it "captures stderr from a host" do
      expect(local.run_command(target, 'expr 1 / 0').value['stderr']).to match(/division by zero/)
    end

    it "can execute a command containing quotes" do
      expect(local.run_command(target, "echo 'hello \" world'").value).to eq(result_value("hello \" world\n"))
    end

    it "can upload a file to a host" do
      contents = "kljhdfg"
      with_tempfile_containing('upload-test', contents) do |file|
        local.upload(target, file.path, "/tmp/upload-test")

        expect(
          local.run_command(target, "cat /tmp/upload-test")['stdout']
        ).to eq(contents)

        local.run_command(target, "rm /tmp/upload-test")
      end
    end

    it "can run a script remotely" do
      contents = "#!/bin/sh\necho hellote"
      with_tempfile_containing('script test', contents) do |file|
        expect(
          local.run_script(target, file.path, [])['stdout']
        ).to eq("hellote\n")
      end
    end

    it "can run a script remotely with quoted arguments" do
      with_tempfile_containing('script-test-ssh-quotes', echo_script) do |file|
        expect(
          local.run_script(target,
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
      contents = "#!/bin/sh\necho $1\necho $2"
      arguments = ['non-sensitive-arg',
                   make_sensitive('$ecret!')]
      with_tempfile_containing('sensitive_test', contents) do |file|
        expect(
          local.run_script(target, file.path, arguments)['stdout']
        ).to eq("non-sensitive-arg\n$ecret!\n")
      end
    end

    it "escapes unsafe shellwords in arguments" do
      with_tempfile_containing('script-test-ssh-escape', echo_script) do |file|
        expect(
          local.run_script(target,
                           file.path,
                           ['echo $HOME; cat /etc/passwd'])['stdout']
        ).to eq(<<SHELLWORDS)
echo $HOME; cat /etc/passwd
SHELLWORDS
      end
    end

    it "can run a task" do
      contents = "#!/bin/sh\necho ${PT_message_one} ${PT_message_two}"
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_task_containing('tasks_test', contents, 'environment') do |task|
        expect(local.run_task(target, task, arguments).message.strip)
          .to eq('Hello from task Goodbye')
      end
    end

    it "can run a task passing input on stdin" do
      contents = "#!/bin/sh\ncat"
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_task_containing('tasks_test_stdin', contents, 'stdin') do |task|
        expect(local.run_task(target, task, arguments).value)
          .to eq("message_one" => "Hello from task", "message_two" => "Goodbye")
      end
    end

    it "serializes hashes as json in environment input" do
      contents = "#!/bin/sh\nprintenv PT_message"
      arguments = { message: { key: 'val' } }
      with_task_containing('tasks_test_hash', contents, 'environment') do |task|
        expect(local.run_task(target, task, arguments).value)
          .to eq('key' => 'val')
      end
    end

    it "can run a task passing input on stdin and environment" do
      contents = <<SHELL
#!/bin/sh
echo ${PT_message_one} ${PT_message_two}
cat
SHELL
      arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
      with_task_containing('tasks-test-both', contents, 'both') do |task|
        expect(local.run_task(target, task, arguments).message).to eq(<<SHELL.strip)
Hello from task Goodbye
{\"message_one\":\"Hello from task\",\"message_two\":\"Goodbye\"}
SHELL
      end
    end

    it "can run a task with non-string parameters" do
      contents = <<SHELL
#!/bin/sh
echo ${PT_message} ${PT_number}
cat
SHELL
      arguments = { message: 'Hello from task', number: 12 }
      with_task_containing('tasks-test-both', contents, 'both') do |task|
        expect(local.run_task(target, task, arguments).message).to eq(<<SHELL.strip)
Hello from task 12
{\"message\":\"Hello from task\",\"number\":12}
SHELL
      end
    end

    it "can run a task with params containing quotes" do
      contents = <<SHELL
#!/bin/sh
echo ${PT_message}
SHELL

      arguments = { message: "foo ' bar ' baz" }
      with_task_containing('tasks_test_quotes', contents, 'both') do |task|
        expect(local.run_task(target, task, arguments).message.strip).to eq "foo ' bar ' baz"
      end
    end

    it "can run a task with Sensitive params via environment" do
      contents = <<SHELL
#!/bin/sh
echo ${PT_sensitive_string}
echo ${PT_sensitive_array}
echo ${PT_sensitive_hash}
SHELL
      deep_hash = { 'k' => make_sensitive('v') }
      arguments = { 'sensitive_string' => make_sensitive('$ecret!'),
                    'sensitive_array'  => make_sensitive([1, 2, make_sensitive(3)]),
                    'sensitive_hash'   => make_sensitive(deep_hash) }
      with_task_containing('tasks_test_sensitive', contents, 'both') do |task|
        expect(local.run_task(target, task, arguments).message.strip).to eq(<<SHELL.strip)
$ecret!
[1,2,3]
{"k":"v"}
SHELL
      end
    end

    it "can run a task with Sensitive params via stdin" do
      contents = <<SHELL
#!/bin/sh
cat -
SHELL
      arguments = { 'sensitive_string' => make_sensitive('$ecret!') }
      with_task_containing('tasks_test_sensitive', contents, 'stdin') do |task|
        expect(local.run_task(target, task, arguments).value)
          .to eq("sensitive_string" => "$ecret!")
      end
    end

    context "when implementations are provided" do
      let(:contents) { "#!/bin/sh\necho ${PT_message_one} ${PT_message_two}" }
      let(:arguments) { { message_one: 'Hello from task', message_two: 'Goodbye' } }

      it "runs a task requires 'shell'" do
        with_task_containing('tasks_test', contents, 'environment') do |task|
          task['metadata']['implementations'] = [{ 'name' => 'tasks_test', 'requirements' => ['shell'] }]
          expect(local.run_task(target, task, arguments).message.chomp)
            .to eq('Hello from task Goodbye')
        end
      end

      it "runs a task with the implementation's input method" do
        with_task_containing('tasks_test', contents, 'stdin') do |task|
          task['metadata']['implementations'] = [{
            'name' => 'tasks_test', 'requirements' => ['shell'], 'input_method' => 'environment'
          }]
          expect(local.run_task(target, task, arguments).message.chomp)
            .to eq('Hello from task Goodbye')
        end
      end

      it "errors when a task only requires an unsupported requirement" do
        with_task_containing('tasks_test', contents, 'environment') do |task|
          task['metadata']['implementations'] = [{ 'name' => 'tasks_test', 'requirements' => ['powershell'] }]
          expect {
            local.run_task(target, task, arguments)
          }.to raise_error("No suitable implementation of #{task.name} for #{target.name}")
        end
      end

      it "errors when a task only requires an unknown requirement" do
        with_task_containing('tasks_test', contents, 'environment') do |task|
          task['metadata']['implementations'] = [{ 'name' => 'tasks_test', 'requirements' => ['foobar'] }]
          expect {
            local.run_task(target, task, arguments)
          }.to raise_error("No suitable implementation of #{task.name} for #{target.name}")
        end
      end
    end

    context "when it can't upload a file" do
      it 'returns an error result for upload' do
        contents = "kljhdfg"
        with_tempfile_containing('upload-test', contents) do |file|
          expect {
            local.upload(target, file.path, "/tmp/a/non/existent/dir/upload-test")
          }.to raise_error(Bolt::Node::FileError, /No such file or directory/)
        end
      end

      it 'returns an error result for run_script' do
        contents = "#!/bin/sh\necho hellote"
        expect(FileUtils).to receive(:copy_file).and_raise('no write')
        with_tempfile_containing('script test', contents) do |file|
          expect {
            local.run_script(target, file.path, [])
          }.to raise_error(Bolt::Node::FileError, /no write/)
        end
      end

      it 'returns an error result for run_task' do
        contents = "#!/bin/sh\necho -n ${PT_message_one} ${PT_message_two}"
        arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
        expect(FileUtils).to receive(:copy_file).and_raise('no write')
        with_task_containing('tasks_test', contents, 'environment') do |task|
          expect {
            local.run_task(target, task, arguments)
          }.to raise_error(Bolt::Node::FileError, /no write/)
        end
      end
    end

    context "when it can't create a tempdir" do
      before(:each) do
        expect(Dir).to receive(:mktmpdir).with(no_args).and_raise('no tmpdir')
      end

      it 'errors when it tries to run a command' do
        expect {
          local.run_command(target, 'echo hello')
        }.to raise_error(/no tmpdir/)
      end

      it 'errors when it tries to run a script' do
        contents = "#!/bin/sh\necho hellote"
        with_tempfile_containing('script test', contents) do |file|
          expect {
            local.run_script(target, file.path, []).error_hash['msg']
          }.to raise_error(/no tmpdir/)
        end
      end

      it "can run a task" do
        contents = "#!/bin/sh\necho -n ${PT_message_one} ${PT_message_two}"
        arguments = { message_one: 'Hello from task', message_two: 'Goodbye' }
        with_task_containing('tasks_test', contents, 'environment') do |task|
          expect {
            local.run_task(target, task, arguments)
          }.to raise_error(/no tmpdir/)
        end
      end
    end

    context 'when tmpdir is specified' do
      let(:tmpdir) { '/tmp/mytempdir' }
      let(:target2) { Bolt::Target.new('local://anything', 'tmpdir' => tmpdir) }

      after(:each) do
        local.run_command(target, "rm -rf #{tmpdir}")
      end

      it "run_command errors when tmpdir doesn't exist" do
        expect {
          local.run_command(target2, 'echo hello')
        }.to raise_error(Errno::ENOENT, /No such file or directory.*#{Regexp.escape(tmpdir)}/)
      end

      it "run_script errors when tmpdir doesn't exist" do
        contents = "#!/bin/sh\n echo $0"
        with_tempfile_containing('script dir', contents) do |file|
          expect {
            local.run_script(target2, file.path, [])
          }.to raise_error(Errno::ENOENT, /No such file or directory.*#{Regexp.escape(tmpdir)}/)
        end
      end

      it 'uploads a script to the specified tmpdir' do
        local.run_command(target, "mkdir #{tmpdir}")
        contents = "#!/bin/sh\n echo $0"
        with_tempfile_containing('script dir', contents) do |file|
          expect(local.run_script(target2, file.path, [])['stdout']).to match(/#{Regexp.escape(tmpdir)}/)
        end
      end
    end
  end
end
