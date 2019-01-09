# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/task'
require 'plan_executor/executor'
require 'plan_executor/config'
require 'bolt/plan_result'
require 'bolt/target'

describe "PlanExecutor::Executor" do
  include BoltSpec::Task

  let(:mock_client) { instance_double("OrchestratorClient", run_task: client_results) }
  let(:executor) { PlanExecutor::Executor.new('22', mock_client) }
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

  before(:each) do
    allow(OrchestratorClient).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:config).and_return(PlanExecutor::Config.new)
  end

  it "sets the api plan job id" do
    expect(api.plan_job).to eq('22')
  end

  context 'finishing a plan' do
    it "finishes a plan" do
      expect(api).to receive(:finish_plan)
        .and_return(Bolt::PlanResult.new(client_results, 'success'))
      expect(executor.finish_plan(client_results)).to be_a(Bolt::PlanResult)
    end

    it "catches finish_plan failures" do
      expect(api).to receive(:finish_plan).and_raise(StandardError)
      expect { executor.finish_plan(client_results) }.to raise_error(StandardError)
      logs = @log_output.readlines
      expect(logs).to include(/DEBUG.*#{client_results.to_json}/)
    end
  end

  context 'running a command' do
    it 'executes on all nodes' do
      expect(api).to receive(:run_command)
        .with(targets, command, {})
        .and_return(node_results)

      executor.run_command(targets, command, {})
    end

    it 'passes options' do
      expect(api).to receive(:run_command)
        .with(targets, command, 'service_url' => 'abcde.com')
        .and_return(node_results)

      executor.run_command(targets, command, 'service_url' => 'abcde.com')
    end

    it 'catches errors' do
      expect(api).to receive(:run_command)
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
      expect(api).to receive(:run_script)
        .with(targets, script, [], {})
        .and_return(node_results)

      results = executor.run_script(targets, script, [], {})
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
      end
    end

    it 'catches errors' do
      expect(api)
        .to receive(:run_script)
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
        .to receive(:run_task)
        .with(targets, task_type(task), task_arguments, task_options)
        .and_return(node_results)

      results = executor.run_task(targets, mock_task(task), task_arguments, task_options)
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
        expect(result).to be_success
      end
    end

    it 'catches errors' do
      expect(api)
        .to receive(:run_task)
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
        .to receive(:file_upload)
        .with(targets, script, dest, {})
        .and_return(node_results)

      results = executor.upload_file(targets, script, dest)
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
      end
    end

    it 'catches errors' do
      expect(api)
        .to receive(:file_upload)
        .with(targets, script, dest, {})
        .and_raise(Bolt::Error, 'failed', 'my-exception')

      executor.upload_file(targets, script, dest) do |result|
        expect(result.error_hash['msg']).to eq('failed')
        expect(result.error_hash['kind']).to eq('my-exception')
      end
    end
  end

  it "returns and notifies an error result" do
    expect(mock_client)
      .to receive(:run_task)
      .and_raise(
        Bolt::Node::ConnectError.new('Authentication failed', 'AUTH_ERROR')
      )

    results = executor.run_command(targets, command)

    results.each do |result|
      expect(result.error_hash['msg']).to eq('Authentication failed')
      expect(result.error_hash['kind']).to eq('puppetlabs.tasks/connect-error')
    end
  end

  it "returns an exception result if the connect raises an unhandled error" do
    expect(mock_client).to receive(:run_task).and_raise("reset")

    results = executor.run_command(targets, command)
    results.each do |result|
      expect(result.error_hash['kind']).to eq('puppetlabs.tasks/exception-error')
    end
  end
end
