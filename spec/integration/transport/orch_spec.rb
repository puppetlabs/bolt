# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/files'
require 'bolt_spec/sensitive'
require 'bolt_spec/task'
require 'bolt/transport/orch'
require 'bolt/plan_result'
require 'bolt/inventory'
require 'open3'
require 'orchestrator_client'

require 'shared_examples/transport'

describe Bolt::Transport::Orch, orchestrator: true do
  include BoltSpec::Files
  include BoltSpec::Sensitive
  include BoltSpec::Task

  let(:transport)   { 'pcp' }
  let(:hostname)    { 'localhost' }
  let(:config)      { Bolt::Config.default }
  let(:plugins)     { Bolt::Plugin.setup(config, nil) }
  let(:inv_data)    {
    { 'config' => {
      'pcp' => {
        "service-url" =>
        "https://orchestrator.com:8143"
      }
    } }
  }
  let(:inventory) do
    Bolt::Inventory.create_version(inv_data, config.transport, config.transports, plugins)
  end
  let(:target)      { make_target }
  let(:targets)     { inventory.get_targets(['pcp://node1', 'node2']) }
  let(:mock_client) { instance_double("OrchestratorClient", run_task: results) }

  let(:orch)        { Bolt::Transport::Orch.new }

  let(:results) do
    [{ 'name' => 'localhost', 'state' => result_state, 'result' => result }]
  end

  let(:mtask)        { mock_task('foo', 'foo/tasks/init', 'input') }
  let(:params)       { { 'param' => 'val' } }
  let(:result_state) { 'finished' }
  let(:result)       { { '_output' => 'ok' } }
  let(:base_path)    { File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..')) }

  before(:each) do
    allow(OrchestratorClient).to receive(:new).and_return(mock_client)
  end

  describe "when orchestrator_client-ruby is used" do
    it "bolt sets User-Agent header option to Bolt/${version}" do
      with_tempfile_containing('token', 'faketoken') do |conf|
        config = {
          'service-url' => 'https://foo.bar:8143',
          'cacert' => conf.path,
          'token-file' => conf.path
        }
        allow(OrchestratorClient).to receive(:new).and_call_original
        c = Bolt::Transport::Orch::Connection.new(config, nil, orch.logger)
        expect(c.instance_variable_get(:@client).config.config["User-Agent"]).to eq("Bolt/#{Bolt::VERSION}")
      end
    end

    it "bolt sets read-timeout" do
      with_tempfile_containing('token', 'faketoken') do |conf|
        config = {
          'service-url' => 'https://foo.bar:8143',
          'cacert' => conf.path,
          'token-file' => conf.path,
          'read-timeout' => 30
        }
        allow(OrchestratorClient).to receive(:new).and_call_original
        c = Bolt::Transport::Orch::Connection.new(config, nil, orch.logger)
        expect(c.instance_variable_get(:@client).config['read-timeout']).to eq(30)
      end
    end

    it "sets the port to 8143 if one is not specified" do
      with_tempfile_containing('token', 'faketoken') do |conf|
        config = {
          'service-url' => 'https://foo.bar',
          'cacert' => conf.path,
          'token-file' => conf.path
        }
        allow(OrchestratorClient).to receive(:new).and_call_original
        c = Bolt::Transport::Orch::Connection.new(config, nil, orch.logger)
        expect(c.instance_variable_get(:@client).config.config["service-url"]).to eq("https://foo.bar:8143")
      end
    end

    it "bolt expands file paths for cacert and token-file" do
      config = {
        'service-url' => 'https://foo.bar:8143',
        'cacert' => '~/foo/bar',
        'token-file' => '~/bar/foo'
      }
      expected = {
        "service-url" => "https://foo.bar:8143",
        "token-file" => "#{Dir.home}/bar/foo",
        "cacert" => "#{Dir.home}/foo/bar",
        "User-Agent" => "Bolt/#{Bolt::VERSION}"
      }
      expect(OrchestratorClient).to receive(:new).with(expected, true)
      Bolt::Transport::Orch::Connection.new(config, nil, orch.logger)
    end
  end

  describe :build_request do
    let(:conn) { Bolt::Transport::Orch::Connection.new(targets.first.options, nil, orch.logger) }

    it "gets the task name from the task" do
      body = conn.build_request(targets, mtask, {})
      expect(body[:task]).to eq('foo')
    end

    it "sets environment" do
      set_config(targets.first, 'task-environment' => 'development')
      body = conn.build_request(targets, mtask, {})
      expect(body[:environment]).to eq('development')
    end

    it "omits noop if unspecified" do
      body = conn.build_request(targets, mtask, {})
      expect(body[:noop]).to be_nil
    end

    it "sets noop to true if specified noop" do
      body = conn.build_request(targets, mtask, '_noop' => true)
      expect(body[:noop]).to eq(true)
    end

    it "sets the parameters" do
      params = { 'foo' => 1, 'bar' => 'baz' }
      body = conn.build_request(targets, mtask, params)
      expect(body[:params]).to eq(params)
    end

    it "doesn't pass noop as a parameter" do
      params = { 'foo' => 1, 'bar' => 'baz' }
      body = conn.build_request(targets, mtask, params.merge('_noop' => true))
      expect(body[:params]).to eq(params)
    end

    it "doesn't pass _task as a parameter" do
      params = { 'foo' => 1, 'bar' => 'baz' }
      body = conn.build_request(targets, mtask, params.merge('_task' => 'my::task'))
      expect(body[:params]).to eq(params)
    end

    it "sets the scope to the list of hosts" do
      body = conn.build_request(targets, mtask, params.merge('_noop' => true))
      expect(body[:scope]).to eq(nodes: %w[node1 node2])
    end

    it "sets description if passed" do
      body = conn.build_request(targets, mtask, params, 'test description')
      expect(body[:description]).to eq('test description')
    end

    it "omits description if not passed" do
      body = conn.build_request(targets, mtask, params, nil)
      expect(body).not_to include(:description)
    end
  end

  describe :process_run_results do
    it "returns a result for every successful node" do
      results = [{ 'name' => 'node1', 'state' => 'finished', 'result' => { '_output' => 'hello' } },
                 { 'name' => 'node2', 'state' => 'finished', 'result' => { '_output' => 'goodbye' } }]
      node_results = orch.process_run_results(targets, results, 'thetask')

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
        node_results = orch.process_run_results(targets, results, 'thetask', ['tomato/soup', 4])

        expect(node_results[0]).to be_success
        expect(node_results[1]).not_to be_success

        error = node_results[1].error_hash
        expect(error['kind']).to eq('puppetlabs.tasks/task-error')
        expect(error['msg']).to match(/The task failed with exit code/)
        expect(error['details']).to include({ 'file' => 'tomato/soup', 'line' => 4 })
      end

      it "returns the error specified by the node" do
        error_result = { '_error' => { 'kind' => 'puppetlabs.orchestrator/arbitrary-failure',
                                       'msg' => 'something went wrong',
                                       'details' => {} } }
        results = [{ 'name' => 'node1', 'state' => 'finished', 'result' => { '_output' => 'hello' } },
                   { 'name' => 'node2', 'state' => 'failed', 'result' => error_result }]
        node_results = orch.process_run_results(targets, results, 'thetask')

        expect(node_results[0]).to be_success
        expect(node_results[1]).not_to be_success

        expect(node_results[1].error_hash).to eq(error_result['_error'])
      end

      it "returns an error for skipped nodes" do
        results = [{ 'name' => 'node1', 'state' => 'finished', 'result' => { '_output' => 'hello' } },
                   # XXX double-check that this is the correct result for a skipped node
                   { 'name' => 'node2', 'state' => 'skipped', 'result' => nil }]
        node_results = orch.process_run_results(targets, results, 'thetask')

        expect(node_results[0]).to be_success
        expect(node_results[1]).not_to be_success

        expect(node_results[1].error_hash).to eq(
          'kind' => 'puppetlabs.tasks/skipped-node',
          'msg' => "Target node2 was skipped",
          'details' => {}
        )
      end
    end
  end

  describe :batches do
    let(:targets) { inventory.get_targets(%w[pcp://a pcp://b pcp://c pcp://d]) }

    it "splits targets in different environments into separate batches" do
      set_config(targets[0], 'task-environment' => 'production')
      set_config(targets[1], 'task-environment' => 'development')
      set_config(targets[2], 'task-environment' => 'test')
      set_config(targets[3], 'task-environment' => 'development')

      batches = Set.new([[targets[0]],
                         [targets[1], targets[3]],
                         [targets[2]]])
      expect(Set.new(orch.batches(targets))).to eq(batches)
    end

    it "splits targets with different urls into separate batches" do
      set_config(targets[1], 'service-url' => 'master2')
      set_config(targets[2], 'service-url' => 'master3')
      set_config(targets[3], 'service-url' => 'master2')

      batches = Set.new([[targets[0]],
                         [targets[1], targets[3]],
                         [targets[2]]])
      expect(Set.new(orch.batches(targets))).to eq(batches)
    end

    it "splits targets with different tokens into separate batches" do
      allow(Bolt::Util).to receive(:validate_file).and_return(true)

      set_config(targets[1], 'token-file' => 'token2')
      set_config(targets[2], 'token-file' => 'token3')
      set_config(targets[3], 'token-file' => 'token2')

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

      node_results = orch.batch_task(targets, mtask, params)
      expect(node_results[0].value).to eq('_output' => 'hello')
      expect(node_results[1].value).to eq('_output' => 'goodbye')
      expect(node_results[0]).to be_success
      expect(node_results[1]).to be_success
    end

    it 'uses plan_task when a plan is running' do
      plan_context = { plan_name: "foo", params: {} }
      orch.plan_context = plan_context

      mock_command_api = instance_double("OrchestratorClient::Client")
      expect(mock_client).to receive(:command).twice.and_return(mock_command_api)
      expect(mock_command_api).to receive(:plan_start).with(plan_context).and_return("name" => "22")

      expect(mock_client).to receive(:run_task).with(hash_including(plan_job: "22")).and_return(results)

      node_results = orch.batch_task(targets, mtask, params)
      expect(node_results[0].value).to eq('_output' => 'hello')
      expect(node_results[1].value).to eq('_output' => 'goodbye')
      expect(node_results[0]).to be_success
      expect(node_results[1]).to be_success

      expect(mock_command_api).to receive(:plan_finish).with(plan_job: "22", result: results, status: 'success')
      orch.finish_plan(Bolt::PlanResult.new(results, 'success'))
    end

    it 'uses task when the plan cannot be started' do
      plan_context = { plan_name: "foo", params: {} }
      orch.plan_context = plan_context

      mock_command_api = instance_double("OrchestratorClient::Client")
      expect(mock_client).to receive(:command).and_return(mock_command_api)
      expect(mock_command_api).to receive(:plan_start).with(plan_context).and_raise(
        OrchestratorClient::ApiError.new({}, "404")
      )

      expect(mock_client).to receive(:run_task).with(satisfy do |opts|
        !opts.include?(:plan_job)
      end).and_return(results)

      node_results = orch.batch_task(targets, mtask, params)
      expect(node_results[0].value).to eq('_output' => 'hello')
      expect(node_results[1].value).to eq('_output' => 'goodbye')
      expect(node_results[0]).to be_success
      expect(node_results[1]).to be_success
    end

    it 'emits events for each target' do
      allow(mock_client).to receive(:run_task).and_return(results)

      events = []
      results = orch.batch_task(targets, mtask, params) do |event|
        events << event
      end

      results.each do |result|
        expect(events).to include(type: :node_start, target: result.target)
        expect(events).to include(type: :node_result, result: result)
      end
    end

    it 'passes description through if supplied' do
      expect(mock_client).to receive(:run_task).with(include(description: 'test message')).and_return(results)

      orch.batch_task(targets, mtask, params, description: 'test message')
    end

    it "unwraps Sensitive parameters" do
      allow(mock_client).to receive(:run_task).and_return(results)
      sensitive_params = { 'sensitive_string' => make_sensitive('$ecret!') }
      expect(mock_client).to receive(:run_task)
        .with(hash_including(params: { "sensitive_string" => "$ecret!" }))

      node_results = orch.batch_task(targets, mtask, sensitive_params)

      expect(node_results[0].value).to eq('_output' => 'hello')
      expect(node_results[1].value).to eq('_output' => 'goodbye')
      expect(node_results[0]).to be_success
      expect(node_results[1]).to be_success
    end

    context "when implementations are provided" do
      let(:files) { [{ 'name' => 'tasks_test', 'path' => '/who/cares' }] }
      let(:implementations) { [{ 'name' => 'tasks_test', 'requirements' => ['shell'] }] }
      let(:mtask) { Bolt::Task.new('foo', { 'implementations' => implementations }, files) }

      it "runs a task" do
        allow(mock_client).to receive(:run_task).and_return(results)

        node_results = orch.batch_task(targets, mtask, params)
        expect(node_results[0].value).to eq('_output' => 'hello')
        expect(node_results[1].value).to eq('_output' => 'goodbye')
        expect(node_results[0]).to be_success
        expect(node_results[1]).to be_success
      end
    end

    context "when files are provided", ssh: true do
      let(:files) { [{ 'name' => 'tasks_test', 'path' => '/who/cares' }] }
      let(:mtask) { Bolt::Task.new('foo', { 'files' => %w[a b] }, files) }

      it "runs a task" do
        allow(mock_client).to receive(:run_task).and_return(results)

        node_results = orch.batch_task(targets, mtask, params)
        expect(node_results[0].value).to eq('_output' => 'hello')
        expect(node_results[1].value).to eq('_output' => 'goodbye')
        expect(node_results[0]).to be_success
        expect(node_results[1]).to be_success
      end
    end
  end

  describe :batch_command do
    let(:command) { 'anything' }
    let(:body) {
      {
        task: 'bolt_shim::command',
        params: { 'command' => command }
      }
    }

    let(:results) {
      [{ 'name' => 'node1', 'state' => 'finished', 'result' => { 'stdout' => 'hello', 'exit_code' => 0 } },
       { 'name' => 'node2', 'state' => 'finished', 'result' => { 'stdout' => 'goodbye', 'exit_code' => 0 } }]
    }

    before(:each) do
      expect(mock_client).to receive(:run_task).with(include(body)).and_return(results)
    end

    it 'returns a success' do
      results = orch.batch_command(targets, command)
      expect(results[0]).to be_success
      expect(results[1]).to be_success
      expect(results[0]['stdout']).to eq('hello')
      expect(results[1]['stdout']).to eq('goodbye')
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

    it 'ignores run_as' do
      results = orch.batch_command(targets, command, run_as: 'root')
      expect(results[0]).to be_success
      expect(results[1]).to be_success
    end

    context 'when it fails' do
      let(:results) {
        [{ 'name' => 'node1',
           'state' => 'finished',
           'result' => { 'stderr' => 'bye',
                         '_error' => {
                           'details' => {
                             'exit_code' => 23
                           }
                         } } },
         { 'name' => 'node2', 'state' => 'finished', 'result' => { 'stdout' => 'hi', 'exit_code' => 1 } }]
      }

      it 'returns a failure with stdout, stderr and exit_code' do
        results = orch.batch_command(targets, command, {}, ['/grilled/cheese', 5])

        expect(results[0]).not_to be_success
        expect(results[0]['stderr']).to eq('bye')
        expect(results[0].error_hash['details'])
          .to include({ 'file' => '/grilled/cheese',
                        'line' => 5,
                        'exit_code' => 23 })

        expect(results[1]).not_to be_success
        expect(results[1]['exit_code']).to eq(1)
        expect(results[1]['stdout']).to eq('hi')
      end
    end
  end

  describe :batch_download do
    it 'returns failing results' do
      error_hash = {
        'kind'    => 'bolt/not-supported-error',
        'msg'     => 'pcp transport does not support downloading files',
        'details' => {}
      }

      results = orch.batch_download(targets, 'foo', 'bar')

      expect(results[0]).not_to be_success
      expect(results[0].error_hash).to eq(error_hash)

      expect(results[1]).not_to be_success
      expect(results[1].error_hash).to eq(error_hash)
    end
  end

  describe :batch_upload do
    let(:source_path) { File.join(base_path, 'spec', 'fixtures', 'scripts', 'success.sh') }
    let(:dest_path) { 'success.sh' }
    let(:body) {
      content = Base64.encode64(File.read(source_path))
      mode = File.stat(source_path).mode

      {
        task: 'bolt_shim::upload',
        params: { 'path' => dest_path, 'content' => content, 'mode' => mode, 'directory' => false }
      }
    }

    def upload_message(node)
      { '_output' => "Uploaded '#{source_path}' to '#{node}:#{dest_path}'" }
    end

    let(:results) {
      [{ 'name' => 'node1', 'state' => 'finished', 'result' => upload_message('node1') },
       { 'name' => 'node2', 'state' => 'finished', 'result' => upload_message('node2') }]
    }

    before(:each) do
      expect(mock_client).to receive(:run_task).with(include(body)).and_return(results)
    end

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

    context 'with a directory' do
      let(:source_path) { File.join(base_path, 'spec', 'fixtures', 'scripts') }
      let(:dest_path) { 'scripts' }
      let(:body) {
        mode = File.stat(source_path).mode

        {
          task: 'bolt_shim::upload',
          params: { 'path' => dest_path, 'content' => anything, 'mode' => mode, 'directory' => true }
        }
      }

      it 'should upload a directory' do
        results = orch.batch_upload(targets, source_path, dest_path)
        expect(results[0]).to be_success
        expect(results[1]).to be_success
        expect(results[0].message).to match(/Uploaded '#{source_path}' to '#{targets[0].host}:#{dest_path}/)
        expect(results[1].message).to match(/Uploaded '#{source_path}' to '#{targets[1].host}:#{dest_path}/)
      end
    end
  end

  describe :batch_script do
    let(:args) { ['with spaces', 'nospaces', 'echo $HOME; cat /etc/passwd'] }
    let(:script_path) { File.join(base_path, 'spec', 'fixtures', 'scripts', 'success.sh') }

    let(:body) {
      content = Base64.encode64(File.read(script_path))

      {
        task: 'bolt_shim::script',
        params: { 'content' => content, 'arguments' => args, 'name' => 'success.sh' }
      }
    }

    let(:results) {
      [{ 'name' => 'node1', 'state' => 'finished', 'result' => { '_output' => '', 'exit_code' => 0 } },
       { 'name' => 'node2', 'state' => 'finished', 'result' => { '_output' => '', 'exit_code' => 0 } }]
    }

    before(:each) do |test|
      unless test.metadata[:skip_before]
        expect(mock_client).to receive(:run_task).with(include(body)).and_return(results)
      end
    end

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

    it "unwraps Sensitive parameters", skip_before: true do
      allow(mock_client).to receive(:run_task).and_return(results)
      sensitive_params = { 'sensitive_string' => make_sensitive('$ecret!') }
      expect(mock_client).to receive(:run_task)
        .with(hash_including(params:
                hash_including("arguments" =>
                  hash_including('sensitive_string' => '$ecret!'))))

      results = orch.batch_script(targets, script_path, sensitive_params)

      expect(results[0]).to be_success
      expect(results[1]).to be_success
    end

    context "when the script succeeds" do
      let(:results) {
        [{ 'name' => 'node1', 'state' => 'finished', 'result' => { 'stdout' => 'hello', 'exit_code' => 0 } },
         { 'name' => 'node2', 'state' => 'finished', 'result' => { 'stderr' => 'there', 'exit_code' => 0 } }]
      }

      it 'captures stdout' do
        results = orch.batch_script(targets, script_path, args)
        expect(results[0]['stdout']).to eq('hello')
      end

      it 'captures stderr' do
        results = orch.batch_script(targets, script_path, args)
        expect(results[1]['stderr']).to eq('there')
      end

      it 'ignores run_as' do
        results = orch.batch_script(targets, script_path, args, run_as: 'root')
        expect(results[0]).to be_success
        expect(results[1]).to be_success
      end
    end

    context "when the script fails" do
      let(:results) {
        [{ 'name' => 'node1',
           'state' => 'finished',
           'result' => { 'stdout' => 'hello',
                         '_error' => {
                           'details' => {
                             'exit_code' => 34
                           }
                         } } },
         { 'name' => 'node2', 'state' => 'finished', 'result' => { 'stderr' => 'there', 'exit_code' => 1 } }]
      }

      it 'returns a failure with stdout, stderr and exit_code' do
        results = orch.batch_script(targets, script_path, args, {}, ['/hot/cocoa', 8])

        expect(results[0]).not_to be_success
        expect(results[0]['stdout']).to eq('hello')
        expect(results[0].error_hash['details'])
          .to include({ 'file' => '/hot/cocoa',
                        'line' => 8,
                        'exit_code' => 34 })

        expect(results[1]).not_to be_success
        expect(results[1]['exit_code']).to eq(1)
        expect(results[1]['stderr']).to eq('there')
      end
    end
  end

  describe 'batch_connected?' do
    it 'returns true if all targets are connected' do
      result = { 'items' => targets.map { |_| { 'connected' => true } } }
      expect(mock_client).to receive(:post).with('inventory', nodes: targets.map(&:host)).and_return(result)
      expect(orch.batch_connected?(targets)).to eq(true)
    end

    it 'returns false if all targets are not connected' do
      result = { 'items' => targets.map { |_| { 'connected' => false } } }
      expect(mock_client).to receive(:post).with('inventory', nodes: targets.map(&:host)).and_return(result)
      expect(orch.batch_connected?(targets)).to eq(false)
    end

    it 'returns false if any targets are not connected' do
      result = { 'items' => targets.map { |_| { 'connected' => true } } }
      result['items'][0]['connected'] = false
      expect(mock_client).to receive(:post).with('inventory', nodes: targets.map(&:host)).and_return(result)
      expect(orch.batch_connected?(targets)).to eq(false)
    end
  end
end
