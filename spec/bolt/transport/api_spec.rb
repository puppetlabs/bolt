# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/task'
require 'bolt/transport/api'
require 'bolt/target'

describe Bolt::Transport::Api do
  include BoltSpec::Task

  let(:results) do
    [{ 'name' => 'localhost',
       'state' => 'finished',
       'result' => { '_output' => 'ok' } }]
  end
  let(:mock_client) { instance_double("OrchestratorClient", run_task: results) }
  let(:mtask) { mock_task('foo', 'foo/tasks/init', 'input') }
  let(:api) { Bolt::Transport::Api.new }

  let(:targets) do
    [Bolt::Target.new('pcp://node1').update_conf(Bolt::Config.default.transport_conf),
     Bolt::Target.new('node2').update_conf(Bolt::Config.default.transport_conf)]
  end

  before(:each) do
    allow(OrchestratorClient).to receive(:new).and_return(mock_client)
  end

  it "does not send start_plan command" do
    plan_context = { plan_name: "foo", params: {} }
    api.plan_context = plan_context

    mock_command_api = instance_double("OrchestratorClient::Client")
    allow(mock_client).to receive(:command)
    expect(mock_command_api).not_to receive(:plan_start)

    api.batch_task(targets, mtask, {})
  end

  describe '#get_connection' do
    it 'returns API connection' do
      expect(api.get_connection(targets.first.options))
        .to be_a(Bolt::Transport::Api::Connection)
    end
  end

  # Since we copy-pasted the orch connection file, this adds tests around
  # conection to make sure the api connection stays up to date
  describe 'batch_connected?' do
    it 'returns true if all targets are connected' do
      result = { 'items' => targets.map { |_| { 'connected' => true } } }
      expect(mock_client).to receive(:post).with('inventory', nodes: targets.map(&:host)).and_return(result)
      expect(api.batch_connected?(targets)).to eq(true)
    end

    it 'returns false if all targets are not connected' do
      result = { 'items' => targets.map { |_| { 'connected' => false } } }
      expect(mock_client).to receive(:post).with('inventory', nodes: targets.map(&:host)).and_return(result)
      expect(api.batch_connected?(targets)).to eq(false)
    end

    it 'returns false if any targets are not connected' do
      result = { 'items' => targets.map { |_| { 'connected' => true } } }
      result['items'][0]['connected'] = false
      expect(mock_client).to receive(:post).with('inventory', nodes: targets.map(&:host)).and_return(result)
      expect(api.batch_connected?(targets)).to eq(false)
    end
  end
end
