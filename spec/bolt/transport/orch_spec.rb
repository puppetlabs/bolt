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
    [Bolt::Target.new('pcp://node1').update_conf(Bolt::Config.new.transport_conf),
     Bolt::Target.new('node2').update_conf(Bolt::Config.new.transport_conf)]
  end

  let(:mock_client) { instance_double("OrchestratorClient", run_task: results) }

  let(:orch) do
    orch = Bolt::Transport::Orch.new({})
    allow(orch).to receive(:create_client).and_return(mock_client)
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

  describe :batches do
    let(:targets) do
      [Bolt::Target.new('a', orch_task_environment: 'production'),
       Bolt::Target.new('b', orch_task_environment: 'development'),
       Bolt::Target.new('c', orch_task_environment: 'test'),
       Bolt::Target.new('d', orch_task_environment: 'development')]
    end

    it "splits targets in different environments into separate batches" do
      batches = Set.new([[targets[0]],
                         [targets[1], targets[3]],
                         [targets[2]]])
      expect(Set.new(orch.batches(targets))).to eq(batches)
    end
  end

  describe :batch_task do
    let(:results) do
      [{ 'name' => 'node1', 'state' => 'finished', 'result' => { '_output' => 'hello' } },
       { 'name' => 'node2', 'state' => 'finished', 'result' => { '_output' => 'goodbye' } }]
    end

    it "executes a task on a host" do
      allow(mock_client).to receive(:run_task).and_return(results)

      node_results = orch.batch_task(targets, taskpath, 'stdin', params)
      expect(node_results[0].value).to eq('_output' => 'hello')
      expect(node_results[1].value).to eq('_output' => 'goodbye')
      expect(node_results[0]).to be_success
      expect(node_results[1]).to be_success
    end

    it 'emits events for each target' do
      allow(mock_client).to receive(:run_task).and_return(results)

      events = []
      results = orch.batch_task(targets, taskpath, 'stdin', params) do |event|
        events << event
      end

      results.each do |result|
        expect(events).to include(type: :node_start, target: result.target)
        expect(events).to include(type: :node_result, result: result)
      end
    end
  end

  context 'using the bolt task wrapper' do
    before(:each) do
      bolt_task = File.expand_path(File.join(base_path, 'tasks', 'init.rb'))
      allow(mock_client).to(receive(:run_task) do |body|
        Open3.popen3("ruby #{bolt_task};") do |stdin, stdout, stderr, wt|
          stdin.write(params.to_json)
          stdin.close
          output = stdout.read
          err = stderr.read
          exit_code = wt.value.exitstatus
          expect(err).to be_empty
          expect(exit_code).to eq(0)

          body[:scope][:nodes].map do |node|
            { 'name' => node, 'state' => 'finished', 'result' => JSON.parse(output) }
          end
        end
      end)
    end

    describe :batch_command do
      let(:options) { {} }
      let(:params) {
        {
          action: 'command',
          command: command,
          options: options
        }
      }
      let(:command) { 'echo hi!; echo bye >&2' }

      it 'returns a success' do
        results = orch.batch_command(targets, command)
        expect(results[0]).to be_success
        expect(results[1]).to be_success
        expect(results[0]['stdout']).to eq("hi!\n")
        expect(results[0]['stderr']).to eq("bye\n")
      end

      it 'emits events for each target' do
        events = []
        results = orch.batch_command(targets, command) do |event|
          events << event
        end

        results.each do |result|
          expect(events).to include(type: :node_start, target: result.target)
          expect(events).to include(type: :node_result, result: result)
        end
      end

      it 'ignores _run_as' do
        results = orch.batch_command(targets, command, '_run_as' => 'root')
        expect(results[0]).to be_success
        expect(results[1]).to be_success
      end

      context 'when it fails' do
        let(:command) { 'echo hi!; echo bye >&2; exit 23' }

        it 'returns a failure with stdout, stderr and exit_code' do
          results = orch.batch_command(targets, command)

          expect(results[0]).not_to be_success
          expect(results[0]['exit_code']).to eq(23)
          expect(results[0]['stdout']).to eq("hi!\n")
          expect(results[0]).not_to be_success

          expect(results[1]['exit_code']).to eq(23)
          expect(results[1]['stdout']).to eq("hi!\n")
          expect(results[1]['stderr']).to eq("bye\n")
          expect(results[1]['stderr']).to eq("bye\n")
        end
      end
    end

    describe 'uploading files' do
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

      describe :batch_upload do
        it 'should write the file' do
          results = orch.batch_upload(targets, source_path, dest_path)
          expect(results[0]).to be_success
          expect(results[1]).to be_success
          expect(results[0].message).to match(/Uploaded '#{source_path}' to '#{targets[0].host}:#{dest_path}/)
          expect(results[1].message).to match(/Uploaded '#{source_path}' to '#{targets[1].host}:#{dest_path}/)
        end

        it 'emits events for each target' do
          events = []
          results = orch.batch_upload(targets, source_path, dest_path) do |event|
            events << event
          end

          results.each do |result|
            expect(events).to include(type: :node_start, target: result.target)
            expect(events).to include(type: :node_result, result: result)
          end
        end
      end
    end

    describe :batch_script do
      let(:args) { ['with spaces', 'nospaces', 'echo $HOME; cat /etc/passwd'] }
      let(:script_path) { File.join(base_path, 'spec', 'fixtures', 'scripts', 'success.sh') }
      let(:params) {
        content = Base64.encode64(File.read(script_path))

        {
          action: 'script',
          content: content,
          arguments: args
        }
      }

      it 'returns a success' do
        results = orch.batch_script(targets, script_path, args)
        expect(results[0]).to be_success
        expect(results[1]).to be_success
      end

      it 'emits events for each target' do
        events = []
        results = orch.batch_script(targets, script_path, args) do |event|
          events << event
        end

        results.each do |result|
          expect(events).to include(type: :node_start, target: result.target)
          expect(events).to include(type: :node_result, result: result)
        end
      end

      context "when the script succeeds" do
        let(:script_path) { File.join(base_path, 'spec', 'fixtures', 'scripts', 'success.sh') }

        it 'captures stdout' do
          results = orch.batch_script(targets, script_path, args)
          expect(
            results[0]['stdout']
          ).to eq(<<-OUT)
arg: with spaces
arg: nospaces
arg: echo $HOME; cat /etc/passwd
standard out
          OUT
        end

        it 'captures stderr' do
          results = orch.batch_script(targets, script_path, args)
          expect(results[0]['stderr']).to eq("standard error\n")
          expect(results[1]['stderr']).to eq("standard error\n")
        end

        it 'ignores _run_as' do
          results = orch.batch_script(targets, script_path, args, '_run_as' => 'root')
          expect(results[0]).to be_success
          expect(results[1]).to be_success
        end
      end

      context "when the script fails" do
        let(:script_path) { File.join(base_path, 'spec', 'fixtures', 'scripts', 'failure.sh') }

        it 'returns a failure with stdout, stderr and exit_code' do
          results = orch.batch_script(targets, script_path, args)

          expect(results[0]).not_to be_success
          expect(results[0]['exit_code']).to eq(34)
          expect(results[0]['stdout']).to eq("standard out\n")
          expect(results[0]['stderr']).to eq("standard error\n")

          expect(results[1]).not_to be_success
          expect(results[1]['exit_code']).to eq(34)
          expect(results[1]['stdout']).to eq("standard out\n")
          expect(results[1]['stderr']).to eq("standard error\n")
        end
      end
    end
  end
end
