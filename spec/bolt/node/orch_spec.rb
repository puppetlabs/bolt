require 'spec_helper'
require 'bolt_spec/files'
require 'bolt/node'
require 'bolt/node/ssh'
require 'bolt/cli'
require 'open3'

describe Bolt::Orch, orchestrator: true do
  include BoltSpec::Files

  let(:hostname) { "localhost" }
  let(:target) do
    Bolt::Target.from_uri(hostname).update_conf(Bolt::Config.new.transport_conf)
  end

  let(:orch) { Bolt::Orch.new(target) }

  let(:task) { "foo" }
  let(:task_environment) { 'production' }
  let(:taskpath) { "foo/tasks/init" }
  let(:params) { { param: 'val' } }
  let(:scope) { { nodes: [hostname] } }

  let(:noop) { nil }
  let(:result_state) { 'finished' }
  let(:result) { { '_output' => 'ok' } }

  let(:base_path) { File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..')) }

  def mock_client
    body = { task: task, environment: task_environment, noop: noop, params: params, scope: scope }
    results = [{ 'state' => result_state, 'result' => result }]

    orch_client = instance_double("OrchestratorClient")
    orch.instance_variable_set(:@client, orch_client)

    expect(orch_client).to(receive(:run_task).with(body).and_return(results))
  end

  def bolt_task_client
    bolt_task = File.expand_path(File.join(base_path, 'tasks', 'init.rb'))
    body = { task: 'bolt', environment: task_environment, noop: noop, params: params, scope: scope }

    orch_client = instance_double("OrchestratorClient")
    orch.instance_variable_set(:@client, orch_client)
    allow(orch_client).to(receive(:run_task).with(body) do
      Open3.popen3("ruby #{bolt_task};") do |stdin, stdout, stderr, wt|
        stdin.write(params.to_json)
        stdin.close
        output = stdout.read
        err = stderr.read
        exit_code = wt.value.exitstatus
        expect(err).to be_empty
        expect(exit_code).to eq(0)
        [{ 'state' => 'finished', 'result' => JSON.parse(output) }]
      end
    end)
  end

  describe :task_name_from_path do
    it 'finds a namespaced task' do
      expect(orch.task_name_from_path('foo/tasks/bar.sh')).to eq('foo::bar')
    end

    it 'finds the init task with extension' do
      expect(orch.task_name_from_path('foo/tasks/init.sh')).to eq('foo')
    end

    it 'finds the init task without extension' do
      expect(orch.task_name_from_path('foo/tasks/init')).to eq('foo')
    end

    it 'errors when not in a module' do
      expect { orch.task_name_from_path('foo/nottasks/init.sh') }
        .to raise_error(ArgumentError)
    end
  end

  describe :run_task do
    before(:each) do
      mock_client
    end

    it "executes a task on a host" do
      expect(orch.run_task(taskpath, 'stdin', params).value)
        .to eq(result)
    end

    it "returns a success" do
      expect(orch.run_task(taskpath, 'stdin', params)).to be_success
    end

    it 'ignores _run_as' do
      expect(orch.run_task(taskpath, 'stdin', params, '_run_as' => 'root')).to be_success
    end

    context "when running noop" do
      let(:noop) { true }

      it "handles the _noop param" do
        expect(orch.run_task(taskpath, 'stdin', params.merge('_noop' => true))).to be_success
      end
    end

    context "when the task target node was skipped" do
      let(:result_state) { 'skipped' }

      it 'returns a failure' do
        expect(orch.run_task(taskpath, 'stdin', params)).not_to be_success
      end

      it 'includes an appropriate error in the returned result' do
        expect(orch.run_task(taskpath, 'stdin', params).error_hash).to eq(
          'kind' => 'puppetlabs.tasks/skipped-node',
          'msg' => "Node #{hostname} was skipped",
          'details' => {}
        )
      end
    end

    context "when the task failed" do
      let(:result_state) { 'failed' }

      it "returns a failure" do
        expect(orch.run_task(taskpath, 'stdin', params)).not_to be_success
      end

      context "when there is an error and no exitcode" do
        it "does not report success" do
          expect(orch.run_task(taskpath, 'stdin', params)).not_to be_success
        end
      end

      context "when there is an exit_code" do
        let(:result) { { '_error' => { 'details' => { 'exit_code' => '3' } } } }

        it "does not report success" do
          expect(orch.run_task(taskpath, 'stdin', params)).not_to be_success
        end
      end
    end
  end

  describe :run_command do
    let(:options) { {} }
    let(:params) {
      {
        action: 'command',
        command: command,
        options: options
      }
    }

    before(:each) do
      bolt_task_client
    end

    context 'when it succeeds' do
      let(:command) { 'echo hi!; echo bye >&2' }

      it 'returns a success' do
        expect(orch.run_command(command)).to be_success
      end

      it 'captures stdout' do
        expect(orch.run_command(command)['stdout']).to eq("hi!\n")
      end

      it 'captures stderr' do
        expect(orch.run_command(command)['stderr']).to eq("bye\n")
      end

      it 'ignores _run_as' do
        expect(orch.run_command(command, '_run_as' => 'root')).to be_success
      end
    end

    context 'when it fails' do
      let(:command) { 'echo hi!; echo bye >&2; exit 23' }

      it 'returns a failure' do
        expect(orch.run_command(command)).not_to be_success
      end

      it 'captures exit_code' do
        expect(orch.run_command(command)['exit_code']).to eq(23)
      end

      it 'captures stdout' do
        expect(orch.run_command(command)['stdout']).to eq("hi!\n")
      end

      it 'captures stderr' do
        expect(orch.run_command(command)['stderr']).to eq("bye\n")
      end
    end
  end

  describe :upload do
    let(:source_path) { File.join(base_path, 'spec', 'fixtures', 'scripts', 'success.sh') }
    let(:dest_path) { 'success.sh' } # to be prepended with a temp dir in the 'around(:each)' block
    let(:params) {
      content = Base64.encode64(File.read(source_path))
      mode = File.stat(source_path).mode

      {
        action: 'upload',
        path: dest_path,
        content: content,
        mode: mode
      }
    }

    around(:each) do |example|
      Dir.mktmpdir(nil, '/tmp') do |dir|
        dest_path.replace(File.join(dir, dest_path)) # prepend the temp dir to the dest_path

        example.run
      end
    end

    before(:each) do
      bolt_task_client
    end

    it 'should write the file' do
      expect(orch.upload(source_path, dest_path).value).to eq(
        '_output' => "Uploaded '#{source_path}' to '#{hostname}:#{dest_path}'"
      )

      source_mode = File.stat(source_path).mode
      dest_mode = File.stat(dest_path).mode
      expect(dest_mode).to eq(source_mode)

      source_content = File.read(source_path)
      dest_content = File.read(dest_path)
      expect(dest_content).to eq(source_content)
    end
  end

  describe :run_script do
    let(:args) { ['with spaces', 'nospaces', 'echo $HOME; cat /etc/passwd'] }
    let(:params) {
      content = Base64.encode64(File.read(script_path))

      {
        action: 'script',
        content: content,
        arguments: args
      }
    }

    before(:each) do
      bolt_task_client
    end

    context "when the script succeeds" do
      let(:script_path) { File.join(base_path, 'spec', 'fixtures', 'scripts', 'success.sh') }

      it 'returns a success' do
        expect(orch.run_script(script_path, args)).to be_success
      end

      it 'captures stdout' do
        expect(
          orch.run_script(script_path, args)['stdout']
        ).to eq(<<-OUT)
arg: with spaces
arg: nospaces
arg: echo $HOME; cat /etc/passwd
standard out
        OUT
      end

      it 'captures stderr' do
        expect(orch.run_script(script_path, args)['stderr']).to eq("standard error\n")
      end

      it 'ignores _run_as' do
        expect(orch.run_script(script_path, args, '_run_as' => 'root')).to be_success
      end
    end

    context "when the script fails" do
      let(:script_path) { File.join(base_path, 'spec', 'fixtures', 'scripts', 'failure.sh') }

      it 'returns a failure' do
        expect(orch.run_script(script_path, args)).not_to be_success
      end

      it 'captures exit_code' do
        expect(orch.run_script(script_path, args)['exit_code']).to eq(34)
      end

      it 'captures stdout' do
        expect(orch.run_script(script_path, args)['stdout']).to eq("standard out\n")
      end

      it 'captures stderr' do
        expect(orch.run_script(script_path, args)['stderr']).to eq("standard error\n")
      end
    end
  end
end
