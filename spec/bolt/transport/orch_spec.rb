require 'spec_helper'
require 'bolt_spec/files'
require 'bolt/transport/orch'
require 'bolt/cli'
require 'open3'

describe Bolt::Transport::Orch, orchestrator: true do
  include BoltSpec::Files

  let(:hostname) { "localhost" }
  let(:target) do
    Bolt::Target.new(hostname).update_conf(Bolt::Config.new.transport_conf)
  end

  let(:targets) do
    [Bolt::Target.new('node1').update_conf(Bolt::Config.new.transport_conf),
     Bolt::Target.new('node2').update_conf(Bolt::Config.new.transport_conf)]
  end

  let(:orch) do
    client = instance_double("OrchestratorClient", run_task: results)
    orch = Bolt::Transport::Orch.new({})
    allow(orch).to receive(:client).and_return(client)
    orch
  end

  let(:results) do
    [{ 'name' => 'localhost', 'state' => result_state, 'result' => result }]
  end

  let(:taskpath) { "foo/tasks/init" }
  let(:params) { { param: 'val' } }

  let(:result_state) { 'finished' }
  let(:result) { { '_output' => 'ok' } }

  let(:base_path) { File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..')) }

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

  describe :build_request do
    it "gets the task name from the path" do
      body = orch.build_request(targets, 'foo/tasks/bar', {})
      expect(body[:task]).to eq('foo::bar')
    end

    it "gets the task name if it's init" do
      body = orch.build_request(targets, 'foo/tasks/init', {})
      expect(body[:task]).to eq('foo')
    end

    it "sets environment" do
      targets.first.options[:orch_task_environment] = 'development'
      body = orch.build_request(targets, taskpath, {})
      expect(body[:environment]).to eq('development')
    end

    it "omits noop if unspecified" do
      body = orch.build_request(targets, taskpath, {})
      expect(body[:noop]).to be_nil
    end

    it "sets noop to true if specified noop" do
      body = orch.build_request(targets, taskpath, '_noop' => true)
      expect(body[:noop]).to eq(true)
    end

    it "sets the parameters" do
      params = { 'foo' => 1, 'bar' => 'baz' }
      body = orch.build_request(targets, taskpath, params)
      expect(body[:params]).to eq(params)
    end

    it "doesn't pass noop as a parameter" do
      params = { 'foo' => 1, 'bar' => 'baz' }
      body = orch.build_request(targets, taskpath, params.merge('_noop' => true))
      expect(body[:params]).to eq(params)
    end

    it "sets the scope to the list of hosts" do
      body = orch.build_request(targets, taskpath, params.merge('_noop' => true))
      expect(body[:scope]).to eq(nodes: %w[node1 node2])
    end
  end

  describe :process_run_results do
    it "returns a result for every successful node" do
      results = [{ 'name' => 'node1', 'state' => 'finished', 'result' => { '_output' => 'hello' } },
                 { 'name' => 'node2', 'state' => 'finished', 'result' => { '_output' => 'goodbye' } }]
      node_results = orch.process_run_results(targets, results)

      expect(node_results[0]).to be_success
      expect(node_results[1]).to be_success
      expect(node_results[0].target).to eq(targets[0])
      expect(node_results[1].target).to eq(targets[1])
      expect(node_results[0].value).to eq('_output' => 'hello')
      expect(node_results[1].value).to eq('_output' => 'goodbye')
    end

    context 'when a node fails' do
      it "returns failure for only the failed node" do
        results = [{ 'name' => 'node1', 'state' => 'finished', 'result' => { '_output' => 'hello' } },
                   { 'name' => 'node2', 'state' => 'failed', 'result' => { '_output' => 'goodbye' } }]
        node_results = orch.process_run_results(targets, results)

        expect(node_results[0]).to be_success
        expect(node_results[1]).not_to be_success

        error = node_results[1].error_hash
        expect(error['kind']).to eq('puppetlabs.tasks/task-error')
        expect(error['msg']).to match(/The task failed with exit code/)
      end

      it "returns the error specified by the node" do
        error_result = { '_error' => { 'kind' => 'puppetlabs.orchestrator/arbitrary-failure',
                                       'msg' => 'something went wrong',
                                       'details' => {} } }
        results = [{ 'name' => 'node1', 'state' => 'finished', 'result' => { '_output' => 'hello' } },
                   { 'name' => 'node2', 'state' => 'failed', 'result' => error_result }]
        node_results = orch.process_run_results(targets, results)

        expect(node_results[0]).to be_success
        expect(node_results[1]).not_to be_success

        expect(node_results[1].error_hash).to eq(error_result['_error'])
      end

      it "returns an error for skipped nodes" do
        results = [{ 'name' => 'node1', 'state' => 'finished', 'result' => { '_output' => 'hello' } },
                   # XXX double-check that this is the correct result for a skipped node
                   { 'name' => 'node2', 'state' => 'skipped', 'result' => nil }]
        node_results = orch.process_run_results(targets, results)

        expect(node_results[0]).to be_success
        expect(node_results[1]).not_to be_success

        expect(node_results[1].error_hash).to eq(
          'kind' => 'puppetlabs.tasks/skipped-node',
          'msg' => "Node node2 was skipped",
          'details' => {}
        )
      end
    end
  end

  describe :batch_task do
    it "executes a task on a host" do
      results = [{ 'name' => 'node1', 'state' => 'finished', 'result' => { '_output' => 'hello' } },
                 { 'name' => 'node2', 'state' => 'finished', 'result' => { '_output' => 'goodbye' } }]
      allow(orch.client).to receive(:run_task).and_return(results)

      node_results = orch.batch_task(targets, taskpath, 'stdin', params).map(&:value)
      expect(node_results[0].value).to eq('_output' => 'hello')
      expect(node_results[1].value).to eq('_output' => 'goodbye')
      expect(node_results[0]).to be_success
      expect(node_results[1]).to be_success
    end
  end

  describe :run_task do
    it "executes a task on a host" do
      node_result = orch.run_task(target, taskpath, 'stdin', params)
      expect(node_result.value).to eq(result)
      expect(node_result).to be_success
    end
  end

  context 'using the bolt task wrapper' do
    before(:each) do
      bolt_task = File.expand_path(File.join(base_path, 'tasks', 'init.rb'))
      allow(orch.client).to(receive(:run_task) do
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

    describe :run_command do
      let(:options) { {} }
      let(:params) {
        {
          action: 'command',
          command: command,
          options: options
        }
      }

      context 'when it succeeds' do
        let(:command) { 'echo hi!; echo bye >&2' }

        it 'returns a success' do
          expect(orch.run_command(target, command)).to be_success
        end

        it 'captures stdout' do
          expect(orch.run_command(target, command)['stdout']).to eq("hi!\n")
        end

        it 'captures stderr' do
          expect(orch.run_command(target, command)['stderr']).to eq("bye\n")
        end

        it 'ignores _run_as' do
          expect(orch.run_command(target, command, '_run_as' => 'root')).to be_success
        end
      end

      context 'when it fails' do
        let(:command) { 'echo hi!; echo bye >&2; exit 23' }

        it 'returns a failure' do
          expect(orch.run_command(target, command)).not_to be_success
        end

        it 'captures exit_code' do
          expect(orch.run_command(target, command)['exit_code']).to eq(23)
        end

        it 'captures stdout' do
          expect(orch.run_command(target, command)['stdout']).to eq("hi!\n")
        end

        it 'captures stderr' do
          expect(orch.run_command(target, command)['stderr']).to eq("bye\n")
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

      it 'should write the file' do
        expect(orch.upload(target, source_path, dest_path).value).to eq(
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

      context "when the script succeeds" do
        let(:script_path) { File.join(base_path, 'spec', 'fixtures', 'scripts', 'success.sh') }

        it 'returns a success' do
          expect(orch.run_script(target, script_path, args)).to be_success
        end

        it 'captures stdout' do
          expect(
            orch.run_script(target, script_path, args)['stdout']
          ).to eq(<<-OUT)
arg: with spaces
arg: nospaces
arg: echo $HOME; cat /etc/passwd
standard out
          OUT
        end

        it 'captures stderr' do
          expect(orch.run_script(target, script_path, args)['stderr']).to eq("standard error\n")
        end

        it 'ignores _run_as' do
          expect(orch.run_script(target, script_path, args, '_run_as' => 'root')).to be_success
        end
      end

      context "when the script fails" do
        let(:script_path) { File.join(base_path, 'spec', 'fixtures', 'scripts', 'failure.sh') }

        it 'returns a failure' do
          expect(orch.run_script(target, script_path, args)).not_to be_success
        end

        it 'captures exit_code' do
          expect(orch.run_script(target, script_path, args)['exit_code']).to eq(34)
        end

        it 'captures stdout' do
          expect(orch.run_script(target, script_path, args)['stdout']).to eq("standard out\n")
        end

        it 'captures stderr' do
          expect(orch.run_script(target, script_path, args)['stderr']).to eq("standard error\n")
        end
      end
    end
  end
end
