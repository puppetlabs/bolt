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
  let(:http_client) { double('http_client') }
  let(:mock_logger) { instance_double("Logging.logger") }
  let(:mtask) { mock_task('foo', 'foo/tasks/init', 'input') }
  let(:subject) { PlanExecutor::OrchClient.new('23', http_client, mock_logger) }

  let(:targets) do
    [Bolt::Target.new('pcp://node1').update_conf(Bolt::Config.default.transport_conf),
     Bolt::Target.new('node2').update_conf(Bolt::Config.default.transport_conf)]
  end

  def response(body, status = 200)
    double('response', status: status, body: body)
  end

  describe '#send_request' do
    let(:job_id) { 'https://example.com/orchestrator/v1/jobs/5' }
    let(:job_nodes_id) { "#{job_id}/nodes" }
    let(:job_created) { { 'job' => { 'id' => job_id } } }
    let(:job_running) { { 'state' => 'running', 'nodes' => { 'id' => job_nodes_id } } }
    let(:job_finished) { { 'state' => 'finished', 'nodes' => { 'id' => job_nodes_id } } }
    let(:job_nodes) { { 'items' => results } }

    it "sends correct request" do
      allow(http_client).to receive(:get).with(job_id).and_return(response(job_finished))
      allow(http_client).to receive(:get).with(job_nodes_id).and_return(response(job_nodes))

      expect(http_client).to receive(:post)
        .with('internal/plan_task',
              hash_including(task: 'foo',
                             scope: { nodes: targets.map(&:host) },
                             plan_job: '23'))
        .and_return(response(job_created, 202))

      subject.send_request(targets, mtask, {})
    end

    it "polls until the job finishes" do
      allow(subject).to receive(:sleep)

      expect(http_client).to receive(:post)
        .with('internal/plan_task', anything)
        .and_return(response(job_created, 202)).ordered
      expect(http_client).to receive(:get).with(job_id).and_return(response(job_running)).ordered
      expect(http_client).to receive(:get).with(job_id).and_return(response(job_running)).ordered
      expect(http_client).to receive(:get).with(job_id).and_return(response(job_running)).ordered
      expect(http_client).to receive(:get).with(job_id).and_return(response(job_finished)).ordered
      expect(http_client).to receive(:get).with(job_nodes_id).and_return(response(job_nodes)).ordered

      expect(subject.send_request(targets, mtask, {})).to eq(results)
    end

    it "fails if the job can't be started" do
      allow(http_client).to receive(:post).and_return(response({ 'msg' => 'something went wrong' }, 400))

      expect { subject.send_request(targets, mtask, {}) }.to raise_error(Bolt::Error, /something went wrong/)
    end
  end

  describe "#finish_plan" do
    it 'sends finish_plan to orchestrator' do
      expect(http_client).to receive(:post)
        .with('internal/plan_finish', plan_job: '23', result: results, status: 'success')
        .and_return(response({}, 202))

      expect(subject.finish_plan(Bolt::PlanResult.new(results, 'success'))).to eq({})
    end
  end
end
