# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/task'
require 'bolt/plan_result'
require 'bolt/target'
require 'plan_executor/orch_client'

describe PlanExecutor::OrchClient do
  include BoltSpec::Task

  let(:results) do
    [{ 'name' => 'localhost',
       'state' => 'finished',
       'result' => { '_output' => 'ok' } }]
  end
  let(:mock_client) { instance_double("OrchestratorClient", run_task: results) }
  let(:mock_command_api) { instance_double("OrchestratorClient::Client") }
  let(:mock_logger) { instance_double("Logging.logger") }
  let(:mtask) { mock_task('foo', 'foo/tasks/init', 'input') }
  let(:api) { PlanExecutor::OrchClient.new('23', mock_client, mock_logger) }

  let(:targets) do
    [Bolt::Target.new('pcp://node1').update_conf(Bolt::Config.default.transport_conf),
     Bolt::Target.new('node2').update_conf(Bolt::Config.default.transport_conf)]
  end

  before(:each) do
    allow(OrchestratorClient).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:config)
      .and_return('service-url' => 'myorch.com')
    # TODO: How do I avoid this?
    allow(mock_logger).to receive(:debug)
  end

  describe '#send_request' do
    it "sends correct request" do
      expect(mock_client).to receive(:run_task)
        .with(hash_including(task: 'foo',
                             scope: { nodes: targets.map(&:host) },
                             plan_job: '23'))
      api.send_request(targets, mtask, {})
    end
  end

  describe "#finish_plan" do
    it 'sends finish_plan to orchestrator' do
      allow(mock_client).to receive(:command).and_return(mock_command_api)

      expect(mock_command_api).to receive(:plan_finish)
        .with(plan_job: "23", result: results, status: 'success')

      api.finish_plan(Bolt::PlanResult.new(results, 'success'))
    end
  end

  describe "#run_task" do
    let(:request) do
      { task: 'foo',
        environment: 'production',
        noop: nil,
        params: {},
        plan_job: '23',
        scope: {
          nodes: targets.map(&:host)
        } }
    end
    it 'runs a task' do
      expect(mock_client).to receive(:run_task)
        .with(request)

      api.run_task(targets, mtask, {}, '')
    end
  end
end
