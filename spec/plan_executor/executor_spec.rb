# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/task'
require 'plan_executor/executor'
require 'bolt/target'

describe "PlanExecutor::Executor" do
  include BoltSpec::Task

  let(:executor) { PlanExecutor::Executor.new(1) }
  let(:api) { executor.transport }
  let(:command) { "hostname" }
  let(:base_path) { File.expand_path(File.join(File.dirname(__FILE__), '..', '..')) }
  let(:script) { File.join(base_path, 'spec', 'fixtures', 'scripts', 'success.sh') }
  let(:dest) { '/tmp/upload' }
  let(:task) { 'service::restart' }
  let(:task_arguments) { { 'name' => 'apache' } }
  let(:task_options) { {} }
  let(:transport) { double('holodeck', initialize_transport: nil) }
  let(:targets) { [Bolt::Target.new("target1"), Bolt::Target.new("target2")] }
  let(:error) { Bolt::Error.new('failed', 'my-exception') }

  let(:result) do
    { 'exit_code' => 0, '_output' => 'ok' }
  end

  let(:node_result) { Bolt::Result.new(targets[0], value: result) }
  let(:node_results) do
    [Bolt::Result.new(targets[0], value: result),
     Bolt::Result.new(targets[1], value: result)]
  end

  let(:client_results) {
    [{ 'name' => 'target1',
       'state' => 'finished',
       'result' => result },
     { 'name' => 'target2',
       'state' => 'finished',
       'results' => result }]
  }

  let(:mock_client) { instance_double("OrchestratorClient", run_task: client_results) }

  def start_event(target)
    { type: :node_start, target: target }
  end

  def success_event(result)
    { type: :node_result, result: result }
  end

  before(:each) do
    allow(OrchestratorClient).to receive(:new).and_return(mock_client)
  end

  context 'running a command' do
    it 'executes on all nodes' do
      expect(api).to receive(:batch_command)
        .with(targets, command, {})
        .and_return(node_results)

      executor.run_command(targets, command, {})
    end

    it 'passes options' do
      expect(api).to receive(:batch_command)
        .with(targets, command, 'service_url' => 'abcde.com')
        .and_return(node_results)

      executor.run_command(targets, command, 'service_url' => 'abcde.com')
    end

    it "yields results" do
      expect(mock_client).to receive(:run_task).and_return(client_results)

      events = []
      results = executor.run_command(targets, command) do |event|
        events << event
      end

      results.each do |result|
        expect(events).to include(success_event(result))
        expect(events).to include(start_event(result.target))
      end
    end

    it 'catches errors' do
      expect(api).to receive(:batch_command)
        .with(targets, command, {})
        .and_raise(error)

      executor.run_command(targets, command) do |result|
        expect(result.error_hash['msg']).to eq('failed')
        expect(result.error_hash['kind']).to eq('my-exception')
      end
    end
  end

  context 'executes running a script' do
    it "on all nodes" do
      expect(api).to receive(:batch_script)
        .with(targets, script, [], {})
        .and_return(node_results)

      results = executor.run_script(targets, script, [], {})
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
      end
    end

    it "yields each result" do
      expect(mock_client).to receive(:run_task).and_return(client_results)

      events = []
      results = executor.run_script(targets, script, []) do |event|
        events << event
      end

      results.each do |result|
        expect(events).to include(success_event(result))
        expect(events).to include(start_event(result.target))
      end
    end

    it 'catches errors' do
      expect(api)
        .to receive(:batch_script)
        .with(targets, script, [], {})
        .and_raise(Bolt::Error, 'failed', 'my-exception')

      executor.run_script(targets, script, []) do |result|
        expect(result.error_hash['msg']).to eq('failed')
        expect(result.error_hash['kind']).to eq('my-exception')
      end
    end
  end

  context 'running a task' do
    it "executes on all nodes" do
      expect(api)
        .to receive(:batch_task)
        .with(targets, task_type(task), task_arguments, task_options)
        .and_return(node_results)

      results = executor.run_task(targets, mock_task(task), task_arguments, task_options)
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
        expect(result).to be_success
      end
    end

    it "yields each result" do
      expect(mock_client).to receive(:run_task).and_return(client_results)

      events = []
      results = executor.run_task(targets, mock_task(task), task_arguments, task_options) do |event|
        events << event
      end

      results.each do |result|
        expect(events).to include(success_event(result))
        expect(events).to include(start_event(result.target))
      end
    end

    it 'catches errors' do
      expect(api)
        .to receive(:batch_task)
        .with(targets, task_type(task), task_arguments, task_options)
        .and_raise(Bolt::Error, 'failed', 'my-exception')

      executor.run_task(targets, mock_task(task), task_arguments, task_options) do |result|
        expect(result.error_hash['msg']).to eq('failed')
        expect(result.error_hash['kind']).to eq('my-exception')
      end
    end
  end

  context 'uploading a file' do
    it "executes on all nodes" do
      expect(api)
        .to receive(:batch_upload)
        .with(targets, script, dest, {})
        .and_return(node_results)

      results = executor.upload_file(targets, script, dest)
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
      end
    end

    it "yields each result" do
      expect(mock_client).to receive(:run_task).and_return(client_results)

      events = []
      results = executor.upload_file(targets, script, dest) do |event|
        events << event
      end

      results.each do |result|
        expect(events).to include(success_event(result))
        expect(events).to include(start_event(result.target))
      end
    end

    it 'catches errors' do
      expect(api)
        .to receive(:batch_upload)
        .with(targets, script, dest, {})
        .and_raise(Bolt::Error, 'failed', 'my-exception')

      executor.upload_file(targets, script, dest) do |result|
        expect(result.error_hash['msg']).to eq('failed')
        expect(result.error_hash['kind']).to eq('my-exception')
      end
    end
  end

  it "returns and notifies an error result" do
    expect(api)
      .to receive(:get_connection)
      .with(targets.first.options)
      .and_raise(
        Bolt::Node::ConnectError.new('Authentication failed', 'AUTH_ERROR')
      )

    notices = []
    results = executor.run_command(targets, command) { |notice| notices << notice }

    results.each do |result|
      expect(result.error_hash['msg']).to eq('Authentication failed')
      expect(result.error_hash['kind']).to eq('puppetlabs.tasks/connect-error')
    end

    expect(notices.count).to eq(4)
    result_notices = notices.select { |notice| notice[:type] == :node_result }.map { |notice| notice[:result] }
    expect(results).to eq(Bolt::ResultSet.new(result_notices))
  end

  it "returns an exception result if the connect raises an unhandled error" do
    expect(api).to receive(:get_connection).and_raise("reset")

    results = executor.run_command(targets, command)
    results.each do |result|
      expect(result.error_hash['kind']).to eq('puppetlabs.tasks/exception-error')
    end
  end
end
