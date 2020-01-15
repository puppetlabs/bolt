# frozen_string_literal: true

require 'spec_helper'
require 'bolt/transport/local'
require 'bolt/target'
require 'bolt/inventory'
require 'bolt/util'
require 'bolt_spec/transport'
require 'bolt_spec/conn'

require 'shared_examples/transport'

describe Bolt::Transport::Local do
  include BoltSpec::Transport

  let(:host_and_port) { "localhost" }
  let(:safe_name) { host_and_port }
  let(:user) { 'runner' }
  let(:password) { 'runner' }
  let(:transport) { :local }
  let(:os_context) { Bolt::Util.windows? ? windows_context : posix_context }
  let(:target) { Bolt::Target.new('local://localhost', transport_conf) }

  it 'is always connected' do
    expect(runner.connected?(target)).to eq(true)
  end

  it 'provides platform specific features' do
    if Bolt::Util.windows?
      expect(runner.provided_features).to eq(['powershell'])
    else
      expect(runner.provided_features).to eq(['shell'])
    end
  end

  include_examples 'transport api'

  context 'running as another user', sudo: true do
    include_examples 'with sudo'

    context "overriding with '_run_as'" do
      let(:config) {
        mk_config('sudo-password' => password, 'run-as' => 'root')
      }
      let(:target) { make_target }

      it "can override run_as for command via an option" do
        expect(runner.run_command(target, 'whoami', run_as: user)['stdout']).to eq("#{user}\n")
      end

      it "can override run_as for script via an option" do
        contents = "#!/bin/sh\nwhoami"
        with_tempfile_containing('script test', contents) do |file|
          expect(runner.run_script(target, file.path, [], run_as: user)['stdout']).to eq("#{user}\n")
        end
      end

      it "can override run_as for task via an option" do
        contents = "#!/bin/sh\nwhoami"
        with_task_containing('tasks_test', contents, 'environment') do |task|
          expect(runner.run_task(target, task, {}, run_as: user).message).to eq("#{user}\n")
        end
      end

      it "can override run_as for file upload via an option" do
        contents = "upload file test as root content"
        dest = '/tmp/root-file-upload-test'
        with_tempfile_containing('tasks test upload as root', contents) do |file|
          expect(runner.upload(target, file.path, dest, run_as: user).message).to match(/Uploaded/)
          expect(runner.run_command(target, "cat #{dest}", run_as: user)['stdout']).to eq(contents)
          expect(runner.run_command(target, "stat -c %U #{dest}", run_as:  user)['stdout'].chomp).to eq(user)
          expect(runner.run_command(target, "stat -c %G #{dest}", run_as:  user)['stdout'].chomp)
            .to eq(user) | eq('docker')
        end

        runner.run_command(target, "rm #{dest}", sudoable: true, run_as: user)
      end
    end

    context "as user with no password" do
      let(:config) {
        mk_config('run-as' => 'root')
      }
      let(:target) { make_target }

      it "returns a failed result when a temporary directory is created" do
        contents = "#!/bin/sh\nwhoami"
        with_tempfile_containing('script test', contents) do |file|
          expect {
            runner.run_script(target, file.path, [])
          }.to raise_error(Bolt::Node::EscalateError,
                           "Sudo password for user #{user} was not provided for #{host_and_port}")
        end
      end
    end
  end

  context 'with large input and output' do
    let(:file_size) { 1011 }
    let(:str) { (0...1024).map { rand(65..90).chr }.join }
    let(:arguments) { { 'input' => str * file_size } }
    let(:ruby_task) do
      <<~TASK
      #!/usr/bin/env ruby
      input = STDIN.read
      STDERR.print input
      STDOUT.print input
      TASK
    end

    it "runs with large input and captures large output" do
      with_task_containing('big_kahuna', ruby_task, 'stdin', '.rb') do |task|
        result = runner.run_task(target, task, arguments).value
        expect(result['input'].bytesize).to eq(file_size * 1024)
        # Ensure the strings are the same
        expect(result['input'][-1024..-1]).to eq(str)
      end
    end

    context 'with run-as', sudo: true do
      let(:config) {
        mk_config('sudo-password' => password, 'run-as' => 'root')
      }
      let(:target) { make_target }

      it "runs with large input and output" do
        with_task_containing('big_kahuna', ruby_task, 'stdin', '.rb') do |task|
          result = runner.run_task(target, task, arguments).value
          expect(result['input'].bytesize).to eq(file_size * 1024)
          expect(result['input'][-1024..-1]).to eq(str)
        end
      end
    end

    context 'with slow input' do
      let(:file_size) { 10 }
      let(:ruby_task) do
        <<~TASK
        #!/usr/bin/env ruby
        while true
          begin
            input = STDIN.readpartial(1024)
            sleep(0.2)
            STDERR.print input
            STDOUT.print input
          rescue EOFError
            break
          end
        end
        TASK
      end

      it "runs with large input and captures large output" do
        with_task_containing('slow_and_steady', ruby_task, 'stdin', '.rb') do |task|
          result = runner.run_task(target, task, arguments).value
          expect(result['input'].bytesize).to eq(file_size * 1024)
          # Ensure the strings are the same
          expect(result['input'][-1024..-1]).to eq(str)
        end
      end
    end
  end

  context 'on windows hosts', windows: true do
    context 'with run-as configured' do
      let(:config) { mk_config('run-as' => 'root') }
      let(:target) { make_target }

      it "warns when trying to use run-as" do
        runner.run_command(target, os_context[:stdout_command][0])
        logs = @log_output.readlines
        expect(logs).to include(/WARN  Bolt::Transport::LocalWindows : run-as is not supported/)
      end
    end

    context 'with empty config' do
      let(:config) { mk_config({}) }
      let(:target) { make_target }

      it "warns when trying to use _run_as" do
        runner.run_command(target, os_context[:stdout_command][0], run_as: user)
        logs = @log_output.readlines
        expect(logs).to include(/WARN  Bolt::Transport::LocalWindows : run-as is not supported/)
      end
    end
  end

  context 'file errors' do
    before(:each) do
      allow_any_instance_of(Bolt::Transport::Local).to receive(:upload).and_raise(
        Bolt::Node::FileError.new("no write", "WRITE_ERROR")
      )
      allow_any_instance_of(Bolt::Transport::LocalWindows).to receive(:upload).and_raise(
        Bolt::Node::FileError.new("no write", "WRITE_ERROR")
      )
      allow_any_instance_of(Bolt::Transport::LocalWindows).to receive(:in_tmpdir).and_raise(
        Bolt::Node::FileError.new("no write", "WRITE_ERROR")
      )
      allow_any_instance_of(Bolt::Transport::Local::Shell).to receive(:with_tempdir).and_raise(
        Bolt::Node::FileError.new("no tmpdir", "TEMDIR_ERROR")
      )
    end

    include_examples 'transport failures'
  end
end
