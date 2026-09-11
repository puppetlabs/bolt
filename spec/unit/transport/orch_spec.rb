# frozen_string_literal: true

require 'spec_helper'
require 'bolt/transport/orch'
require 'bolt/result'

describe Bolt::Transport::Orch do
  let(:orch) { described_class.new }

  def make_target(name, host: nil, options: {})
    double('target', name: name, host: host || name, safe_name: name, options: options)
  end

  describe '#provided_features' do
    it 'returns orchestrator feature' do
      expect(orch.provided_features).to include('puppet-agent')
    end
  end

  describe '#process_run_results' do
    let(:target1) { make_target('target1') }
    let(:target2) { make_target('target2') }
    let(:targets) { [target1, target2] }

    it 'creates successful result for finished state' do
      results = [
        { 'name' => 'target1', 'state' => 'finished', 'result' => { 'key' => 'val' } }
      ]
      bolt_results = orch.process_run_results([target1], results, 'mytask')
      expect(bolt_results.first).to be_ok
      expect(bolt_results.first['key']).to eq('val')
    end

    it 'creates error result when _error is present in finished state' do
      results = [
        {
          'name' => 'target1',
          'state' => 'finished',
          'result' => {
            '_error' => { 'kind' => 'myerror', 'msg' => 'failed', 'details' => {} }
          }
        }
      ]
      bolt_results = orch.process_run_results([target1], results, 'mytask')
      expect(bolt_results.first).not_to be_ok
    end

    it 'normalizes string _error to hash' do
      results = [
        {
          'name' => 'target1',
          'state' => 'finished',
          'result' => { '_error' => 'string error' }
        }
      ]
      bolt_results = orch.process_run_results([target1], results, 'mytask')
      expect(bolt_results.first.error_hash['kind']).to eq('puppetlabs.tasks/task-error')
    end

    it 'normalizes non-hash _error details' do
      results = [
        {
          'name' => 'target1',
          'state' => 'finished',
          'result' => {
            '_error' => { 'kind' => 'myerror', 'msg' => 'fail', 'details' => 'string details' }
          }
        }
      ]
      bolt_results = orch.process_run_results([target1], results, 'mytask')
      expect(bolt_results.first.error_hash['details']).to be_a(Hash)
    end

    it 'creates skipped result for skipped state' do
      results = [
        { 'name' => 'target1', 'state' => 'skipped', 'result' => nil }
      ]
      bolt_results = orch.process_run_results([target1], results, 'mytask')
      expect(bolt_results.first.error_hash['kind']).to eq('puppetlabs.tasks/skipped-node')
    end

    it 'creates failure result for unknown state' do
      results = [
        { 'name' => 'target1', 'state' => 'unknown', 'result' => {} }
      ]
      bolt_results = orch.process_run_results([target1], results, 'mytask')
      expect(bolt_results.first).not_to be_ok
    end

    it 'includes position in error details' do
      results = [
        {
          'name' => 'target1',
          'state' => 'finished',
          'result' => {
            '_error' => { 'kind' => 'myerror', 'msg' => 'fail', 'details' => {} }
          }
        }
      ]
      bolt_results = orch.process_run_results([target1], results, 'mytask', ['/plan.pp', 10])
      expect(bolt_results.first.error_hash['details']['file']).to eq('/plan.pp')
    end
  end

  describe '#batches' do
    it 'groups targets with the same connection options into one batch' do
      targets = [make_target('t1'), make_target('t2'), make_target('t3')]
      batches = orch.batches(targets)
      # All targets have the same options so they go into one batch
      expect(batches.length).to eq(1)
      expect(batches.first.length).to eq(3)
    end
  end

  describe '#batch_task_with' do
    it 'raises NotImplementedError' do
      expect { orch.batch_task_with(nil, nil, nil) }.to raise_error(NotImplementedError)
    end
  end

  describe '#batch_command' do
    let(:target1) { make_target('t1') }

    it 'raises NotImplementedError when env_vars are set' do
      expect do
        orch.batch_command([target1], 'ls', { env_vars: { 'FOO' => 'bar' } })
      end.to raise_error(NotImplementedError, /pcp transport does not support setting environment variables/)
    end
  end

  describe '#batch_script' do
    let(:target1) { make_target('t1') }

    it 'raises NotImplementedError when env_vars are set' do
      expect do
        orch.batch_script([target1], '/path/to/script.sh', [], { env_vars: { 'FOO' => 'bar' } })
      end.to raise_error(NotImplementedError, /pcp transport does not support setting environment variables/)
    end
  end

  describe '#batch_download' do
    let(:target1) { make_target('t1') }
    let(:target2) { make_target('t2') }

    it 'returns error results for each target' do
      results = orch.batch_download([target1, target2], '/remote/src', '/local/dst')
      expect(results.size).to eq(2)
      results.each { |r| expect(r.error_hash['kind']).to eq('bolt/not-supported-error') }
    end

    it 'sets action to download' do
      results = orch.batch_download([target1], '/remote/src', '/local/dst')
      expect(results.first.action).to eq('download')
    end
  end

  describe '#unwrap_bolt_result' do
    let(:target) { make_target('t1') }

    it 'returns the result unchanged when there is an error' do
      result = double('result', error_hash: { 'kind' => 'bolt/error', 'msg' => 'fail', 'details' => {} })
      expect(orch.unwrap_bolt_result(target, result, 'command', 'ls')).to be(result)
    end

    it 'creates a command result when there is no error' do
      result = double('result', error_hash: nil,
                                value: { 'exit_code' => 0, 'stdout' => 'ok', 'stderr' => '' })
      cmd_result = orch.unwrap_bolt_result(target, result, 'command', 'ls')
      expect(cmd_result).to be_a(Bolt::Result)
      expect(cmd_result.action).to eq('command')
    end
  end

  describe '#run_task_job' do
    let(:target1) { make_target('target1') }
    let(:task) { double('task', name: 'test_task') }

    before do
      allow(orch).to receive(:unwrap_sensitive_args).and_return({})
    end

    it 'returns error results when OrchestratorClient::ApiError is raised' do
      require 'orchestrator_client'
      api_error = OrchestratorClient::ApiError.new(
        { 'msg' => 'api error', 'kind' => 'api/error', 'details' => {} }, '400'
      )
      conn = double('connection')
      allow(conn).to receive(:run_task).and_raise(api_error)
      allow(orch).to receive(:get_connection).and_return(conn)
      results = orch.run_task_job([target1], task, {}, {}, [])
      expect(results.first).not_to be_ok
    end

    it 'returns error results when StandardError is raised' do
      conn = double('connection')
      allow(conn).to receive(:run_task).and_raise(StandardError, 'something failed')
      allow(orch).to receive(:get_connection).and_return(conn)
      results = orch.run_task_job([target1], task, {}, {}, [])
      expect(results.first).not_to be_ok
    end
  end

  describe '#select_implementation' do
    let(:target1) { make_target('target1') }

    it 'delegates to task and sets default input method when missing' do
      task = double('task')
      impl = { 'path' => 'foo.sh' }
      allow(task).to receive(:select_implementation).and_return(impl)
      result = orch.select_implementation(target1, task)
      expect(result['path']).to eq('foo.sh')
      expect(result['input_method']).to eq('both')
    end
  end

  describe '#finish_plan' do
    it 'does nothing when result is not a PlanResult' do
      require 'bolt/plan_result'
      expect { orch.finish_plan('just a string') }.not_to raise_error
    end

    it 'calls finish_plan on each connection when result is a PlanResult' do
      require 'bolt/plan_result'
      plan_result = double('plan_result')
      allow(plan_result).to receive(:is_a?).with(Bolt::PlanResult).and_return(true)
      conn = double('connection', key: 'key1')
      allow(conn).to receive(:finish_plan)
      orch.instance_variable_set(:@connections, { 'key1' => conn })
      expect(conn).to receive(:finish_plan).with(plan_result)
      orch.finish_plan(plan_result)
    end

    it 'rescues errors from finish_plan on individual connections' do
      require 'bolt/plan_result'
      plan_result = double('plan_result')
      allow(plan_result).to receive(:is_a?).with(Bolt::PlanResult).and_return(true)
      conn = double('connection', key: 'key1')
      allow(conn).to receive(:finish_plan).and_raise(StandardError, 'connection error')
      orch.instance_variable_set(:@connections, { 'key1' => conn })
      expect { orch.finish_plan(plan_result) }.not_to raise_error
    end
  end
end
