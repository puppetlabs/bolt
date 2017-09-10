require 'spec_helper'
require 'bolt_spec/files'
require 'bolt/node'
require 'bolt/node/ssh'
require 'bolt/cli'
require 'open3'

describe Bolt::Orch, orchestrator: true do
  include BoltSpec::Files

  let(:hostname) { "localhost" }
  let(:user) { "nil" }
  let(:password) { "nil" }
  let(:port) { nil }
  let(:orch) { Bolt::Orch.new(@hostname) }

  let(:task) { @task = "foo" }
  let(:params) { { param: 'val' } }
  let(:scope) { { nodes: [@hostname] } }
  let(:result_state) { 'finished' }
  let(:result) { { '_output' => 'ok' } }
  let(:base_path) do
    File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..'))
  end

  before(:each) do
    Bolt.log_level = Logger::WARN
    @task = "foo"
    @params =  { param: 'val' }
    @scope = { nodes: [@hostname] }
    @result_state = 'finished'
    @result = { '_output' => 'ok' }
  end

  def mock_client
    body = { task: @task, params: @params, scope: @scope }
    results = [{ 'state' => @result_state, 'result' => @result }]

    orch_client = instance_double("OrchestratorClient")
    orch.instance_variable_set(:@client, orch_client)

    expect(orch_client).to(receive(:run_task).with(body).and_return(results))
  end

  def bolt_task_client
    bolt_task = File.expand_path(File.join(base_path, 'tasks', 'init.rb'))
    body = { task: 'bolt', params: @params, scope: @scope }

    orch_client = instance_double("OrchestratorClient")
    orch.instance_variable_set(:@client, orch_client)
    allow(orch_client).to(receive(:run_task).with(body) do
      Open3.popen3("ruby #{bolt_task};") do |stdin, stdout, stderr, wt|
        stdin.write(@params.to_json)
        stdin.close
        output = stdout.read
        err = stderr.read
        exit_code = wt.value.exitstatus
        expect(err).to be_empty
        expect(exit_code).to eq(0)
        result = JSON.parse(output)
        [{ 'state' => 'finished', 'result' => result }]
      end
    end)
  end

  def set_exec_params(command, options = {})
    @params = { action: 'command', command: command, options: options }
  end

  def set_upload_params(source, destination)
    content = File.open(source, &:read)
    content = Base64.encode64(content)
    mode = File.stat(source).mode
    @params = {
      action: 'upload',
      path: destination,
      content: content,
      mode: mode
    }
  end

  def set_script_params(path, _options = {})
    content = File.open(path, &:read)
    content = Base64.encode64(content)
    @params = { action: 'script', content: content }
  end

  describe :_run_task do
    it "executes a task on a host" do
      mock_client
      expect(orch._run_task(@task, 'stdin', @params).value).to eq(@result.to_json)
    end

    it "returns a success" do
      mock_client
      expect(orch._run_task(@task, 'stdin', @params).class).to eq(Bolt::Node::Success)
    end

    context "the task failed" do
      before(:each) { @result_state = 'failed' }

      it "returns a failure for failed" do
        mock_client
        expect(orch._run_task(@task, 'stdin', @params).class).to eq(Bolt::Node::Failure)
      end

      it "adds an unkown exitcode when absent" do
        mock_client
        expect(orch._run_task(@task, 'stdin', @params).exit_code).to eq('unknown')
      end

      it "uses the exitcode when present" do
        @result = { '_error' => { 'details' => { 'exit_code' => '3' } } }
        mock_client
        expect(orch._run_task(task, 'stdin', params).exit_code).to eq('3')
      end
    end
  end

  describe :_run_command do
    context 'when it succeeds' do
      before(:each) do
        @command = 'echo hi!; echo bye >&2'
        set_exec_params(@command)
        bolt_task_client
      end

      it 'it returns the output' do
        expect(orch._run_command(@command).value).to eq("hi!\n")
      end

      it 'it is a success' do
        expect(orch._run_command(@command).class).to eq(Bolt::Node::Success)
      end

      it 'captures stderr' do
        result = orch._run_command(@command)
        result.output.stderr.rewind
        expect(result.output.stderr.read).to eq("bye\n")
      end
    end

    context 'when it fails' do
      before(:each) do
        @command = 'echo hi!; echo bye >&2; exit 23'
        set_exec_params(@command)
        bolt_task_client
      end
      it 'is a failure' do
        expect(orch._run_command(@command).class).to eq(Bolt::Node::Failure)
      end

      it 'captures the exit_code' do
        expect(orch._run_command(@command).exit_code).to eq(23)
      end

      it 'captures stdout' do
        result = orch._run_command(@command)
        result.output.stdout.rewind
        expect(result.output.stdout.read).to eq("hi!\n")
      end

      it 'captures stderr' do
        result = orch._run_command(@command)
        result.output.stderr.rewind
        expect(result.output.stderr.read).to eq("bye\n")
      end
    end
  end

  describe :_upload do
    it 'should write the file' do
      Dir.mktmpdir(nil, '/tmp') do |dir|
        source_path = File.join(base_path, 'spec', 'fixtures', 'scripts', 'success.sh')
        dest_path = File.join(dir, "success.sh")

        set_upload_params(source_path, dest_path)
        bolt_task_client
        result = orch._upload(source_path, dest_path)

        expect(result.class).to eq(Bolt::Node::Success)

        source_mode = File.stat(source_path).mode
        dest_mode = File.stat(dest_path).mode
        expect(dest_mode).to eq(source_mode)

        source_content = File.open(source_path, &:read)
        dest_content = File.open(dest_path, &:read)
        expect(dest_content).to eq(source_content)
      end
    end
  end

  describe :_run_script do
    context "the script succeeds" do
      let(:script_path) do
        File.expand_path(File.join(base_path, 'spec', 'fixtures', 'scripts', 'success.sh'))
      end

      before(:each) do
        set_script_params(script_path)
        bolt_task_client
      end

      it 'is a success' do
        expect(orch._run_script(script_path).class).to eq(Bolt::Node::Success)
      end

      it 'captures stdout' do
        expect(orch._run_script(script_path).value).to eq("standard out\n")
      end

      it 'captures stderr' do
        result = orch._run_script(script_path)
        result.output.stderr.rewind
        expect(result.output.stderr.read).to eq("standard error\n")
      end
    end

    context "when the script fails" do
      let(:script_path) do
        File.expand_path(File.join(base_path, 'spec', 'fixtures', 'scripts', 'failure.sh'))
      end

      before(:each) do
        set_script_params(script_path)
        bolt_task_client
      end

      it 'returns a failure' do
        expect(orch._run_script(script_path).class).to eq(Bolt::Node::Failure)
      end

      it 'captures exit_code' do
        expect(orch._run_script(script_path).exit_code).to eq(34)
      end

      it 'captures stdout' do
        result = orch._run_script(script_path)
        result.output.stdout.rewind
        expect(result.output.stdout.read).to eq("standard out\n")
      end

      it 'captures stderr' do
        result = orch._run_script(script_path)
        result.output.stderr.rewind
        expect(result.output.stderr.read).to eq("standard error\n")
      end
    end
  end
end
