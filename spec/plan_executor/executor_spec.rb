# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/task'
require 'plan_executor/executor'
require 'plan_executor/config'
require 'bolt/plan_result'
require 'bolt/target'

describe "PlanExecutor::Executor" do
  include BoltSpec::Task

  let(:http_client) { double('http_client') }
  let(:executor) { PlanExecutor::Executor.new('22', http_client) }
  let(:targets) { [Bolt::Target.new("target1"), Bolt::Target.new("target2")] }

  let(:result) do
    { 'exit_code' => 0, '_output' => 'ok' }
  end

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

  it "sets the api plan job id" do
    expect(executor.orch_client.plan_job).to eq('22')
  end

  context 'finishing a plan' do
    it "finishes a plan" do
      expect(executor.orch_client).to receive(:finish_plan).and_return({})
      expect(executor.finish_plan(client_results)).to eq({})
    end

    it "catches finish_plan failures" do
      expect(executor.orch_client).to receive(:finish_plan).and_raise(StandardError)
      expect { executor.finish_plan(client_results) }.to raise_error(StandardError)
      logs = @log_output.readlines
      expect(logs).to include(/DEBUG.*#{client_results.to_json}/)
    end
  end

  context 'running a command' do
    it 'executes on all nodes' do
      expect(executor.orch_client).to receive(:run_command)
        .with(targets, 'hostname', {})
        .and_return(node_results)

      executor.run_command(targets, 'hostname', {})
    end

    it 'passes options' do
      expect(executor.orch_client).to receive(:run_command)
        .with(targets, 'hostname', 'service_url' => 'abcde.com')
        .and_return(node_results)

      executor.run_command(targets, 'hostname', 'service_url' => 'abcde.com')
    end

    it 'catches errors' do
      expect(executor.orch_client).to receive(:run_command)
        .with(targets, 'hostname', {})
        .and_raise(Bolt::Error.new('failed', 'my-exception'))

      results = executor.run_command(targets, 'hostname')

      expect(results.length).to eq(1)
      results.each do |result|
        expect(result.error_hash['msg']).to eq('failed')
        expect(result.error_hash['kind']).to eq('my-exception')
      end
    end
  end

  context 'executes running a script' do
    let(:script) { File.join(__dir__, '..', 'fixtures', 'scripts', 'success.sh') }
    it "on all nodes" do
      expect(executor.orch_client).to receive(:run_script)
        .with(targets, script, [], {})
        .and_return(node_results)

      results = executor.run_script(targets, script, [], {})

      expect(results.length).to eq(targets.length)
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
      end
    end

    it 'catches errors' do
      expect(executor.orch_client)
        .to receive(:run_script)
        .with(targets, script, [], {})
        .and_raise(Bolt::Error.new('failed', 'my-exception'))

      results = executor.run_script(targets, script, [])

      expect(results.length).to eq(1)
      results.each do |result|
        expect(result.error_hash['msg']).to eq('failed')
        expect(result.error_hash['kind']).to eq('my-exception')
      end
    end
  end

  context 'running a task' do
    let(:task) { 'service::restart' }
    let(:task_arguments) { { 'name' => 'apache' } }
    let(:task_options) { {} }

    it "executes on all nodes" do
      expect(executor.orch_client)
        .to receive(:run_task)
        .with(targets, task_type(task), task_arguments, task_options)
        .and_return(node_results)

      results = executor.run_task(targets, mock_task(task), task_arguments, task_options)

      expect(results.length).to eq(targets.length)
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
        expect(result).to be_success
      end
    end

    it 'catches errors' do
      expect(executor.orch_client)
        .to receive(:run_task)
        .with(targets, task_type(task), task_arguments, task_options)
        .and_raise(Bolt::Error.new('failed', 'my-exception'))

      results = executor.run_task(targets, mock_task(task), task_arguments, task_options)

      expect(results.length).to eq(1)
      results.each do |result|
        expect(result.error_hash['msg']).to eq('failed')
        expect(result.error_hash['kind']).to eq('my-exception')
      end
    end
  end

  context 'uploading a file' do
    let(:source) { File.join(__dir__, '..', 'fixtures', 'scripts', 'success.sh') }
    let(:dest) { '/tmp/upload' }

    it "executes on all nodes" do
      expect(executor.orch_client)
        .to receive(:file_upload)
        .with(targets, source, dest, {})
        .and_return(node_results)

      results = executor.upload_file(targets, source, dest)

      expect(results.length).to eq(targets.length)
      results.each do |result|
        expect(result).to be_instance_of(Bolt::Result)
      end
    end

    it 'catches errors' do
      expect(executor.orch_client)
        .to receive(:file_upload)
        .with(targets, source, dest, {})
        .and_raise(Bolt::Error.new('failed', 'my-exception'))

      results = executor.upload_file(targets, source, dest)

      expect(results.length).to eq(1)
      results.each do |result|
        expect(result.error_hash['msg']).to eq('failed')
        expect(result.error_hash['kind']).to eq('my-exception')
      end
    end
  end

  it "returns and notifies an error result" do
    expect(executor.orch_client)
      .to receive(:run_command)
      .and_raise(
        Bolt::Node::ConnectError.new('Authentication failed', 'AUTH_ERROR')
      )

    results = executor.run_command(targets, 'hostname')

    results.each do |result|
      expect(result.error_hash['msg']).to eq('Authentication failed')
      expect(result.error_hash['kind']).to eq('puppetlabs.tasks/connect-error')
    end
  end

  it "returns an exception result if the connect raises an unhandled error" do
    expect(executor.orch_client).to receive(:run_command).and_raise("reset")

    results = executor.run_command(targets, 'hostname')
    results.each do |result|
      expect(result.error_hash['kind']).to eq('puppetlabs.tasks/exception-error')
    end
  end
end
