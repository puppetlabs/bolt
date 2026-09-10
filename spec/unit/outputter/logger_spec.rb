# frozen_string_literal: true

require 'spec_helper'
require 'bolt/outputter'
require 'bolt/result_set'

describe Bolt::Outputter::Logger do
  let(:outputter) { described_class.new(false, false) }
  let(:mock_logger) { double('logger') }

  before(:each) do
    outputter.instance_variable_set(:@logger, mock_logger)
  end

  def make_target(name)
    double('target', safe_name: name, name: name)
  end

  def make_result_set(failures: 0, successes: 1)
    target = double('target', name: 'host')
    results = (1..successes).map { double('result', error_hash: nil) }
    results += (1..failures).map { double('result', error_hash: { 'msg' => 'err' }) } if failures > 0
    mock_rs = double('result_set')
    error_results = results.select { |r| r.error_hash }
    allow(mock_rs).to receive(:error_set).and_return(double('error_set', length: error_results.length))
    mock_rs
  end

  describe '#handle_event' do
    it 'dispatches :step_start events' do
      target = make_target('host1')
      expect(mock_logger).to receive(:info).with(/Starting:/)
      outputter.handle_event(type: :step_start, description: 'running task', targets: [target])
    end

    it 'dispatches :step_finish events' do
      result_set = make_result_set
      expect(mock_logger).to receive(:info).with(/Finished:/)
      outputter.handle_event(type: :step_finish, description: 'running task', result: result_set, duration: 1.5)
    end

    it 'dispatches :plan_start events' do
      expect(mock_logger).to receive(:info).with(/Starting: plan/)
      outputter.handle_event(type: :plan_start, plan: 'myplan')
    end

    it 'dispatches :plan_finish events' do
      expect(mock_logger).to receive(:info).with(/Finished: plan/)
      outputter.handle_event(type: :plan_finish, plan: 'myplan', duration: 2.0)
    end

    it 'dispatches :container_start events' do
      expect(mock_logger).to receive(:info).with(/Starting: run container/)
      outputter.handle_event(type: :container_start, image: 'ubuntu:latest')
    end

    it 'dispatches :container_finish events for success' do
      mock_result = double('result', success?: true, object: 'ubuntu:latest')
      expect(mock_logger).to receive(:info).with(/succeeded/)
      outputter.handle_event(type: :container_finish, result: mock_result)
    end

    it 'dispatches :container_finish events for failure' do
      mock_result = double('result', success?: false, object: 'ubuntu:latest')
      expect(mock_logger).to receive(:info).with(/failed/)
      outputter.handle_event(type: :container_finish, result: mock_result)
    end

    it 'dispatches :log events' do
      expect(mock_logger).to receive(:info).with('hello')
      outputter.handle_event(type: :log, level: :info, message: 'hello')
    end

    it 'dispatches :message events' do
      expect(mock_logger).to receive(:warn).with('alert')
      outputter.handle_event(type: :message, level: :warn, message: 'alert')
    end

    it 'dispatches :verbose events' do
      expect(mock_logger).to receive(:debug).with('verbose msg')
      outputter.handle_event(type: :verbose, level: :debug, message: 'verbose msg')
    end

    it 'does nothing for unknown event types' do
      expect(mock_logger).not_to receive(:info)
      expect(mock_logger).not_to receive(:warn)
      outputter.handle_event(type: :unknown_event)
    end
  end

  describe '#log_step_start' do
    it 'logs individual target names when 5 or fewer targets' do
      targets = [make_target('host1'), make_target('host2')]
      expect(mock_logger).to receive(:info).with(/host1, host2/)
      outputter.log_step_start(description: 'running', targets: targets)
    end

    it 'logs target count when more than 5 targets' do
      targets = (1..6).map { |i| make_target("host#{i}") }
      expect(mock_logger).to receive(:info).with(/6 targets/)
      outputter.log_step_start(description: 'running', targets: targets)
    end
  end

  describe '#log_step_finish' do
    it 'uses plural "failures" for 0 failures' do
      result_set = make_result_set(failures: 0)
      expect(mock_logger).to receive(:info).with(/0 failures/)
      outputter.log_step_finish(description: 'task', result: result_set, duration: 1.0)
    end

    it 'uses singular "failure" for exactly 1 failure' do
      result_set = make_result_set(failures: 1)
      expect(mock_logger).to receive(:info).with(/1 failure[^s]/)
      outputter.log_step_finish(description: 'task', result: result_set, duration: 1.0)
    end

    it 'uses plural "failures" for multiple failures' do
      result_set = make_result_set(failures: 3)
      expect(mock_logger).to receive(:info).with(/3 failures/)
      outputter.log_step_finish(description: 'task', result: result_set, duration: 1.0)
    end
  end

  describe '#log_plan_start' do
    it 'logs the plan name' do
      expect(mock_logger).to receive(:info).with(/myplan/)
      outputter.log_plan_start(plan: 'myplan')
    end
  end

  describe '#log_plan_finish' do
    it 'logs the plan name and rounded duration' do
      expect(mock_logger).to receive(:info).with(/myplan.*1\.5/)
      outputter.log_plan_finish(plan: 'myplan', duration: 1.5)
    end
  end

  describe '#log_container_start' do
    it 'logs the container image name' do
      expect(mock_logger).to receive(:info).with(/ubuntu:latest/)
      outputter.log_container_start(image: 'ubuntu:latest')
    end
  end

  describe '#log_container_finish' do
    it 'logs success when result succeeded' do
      mock_result = double('result', success?: true, object: 'my-image')
      expect(mock_logger).to receive(:info).with(/succeeded/)
      outputter.log_container_finish(result: mock_result)
    end

    it 'logs failure when result failed' do
      mock_result = double('result', success?: false, object: 'my-image')
      expect(mock_logger).to receive(:info).with(/failed/)
      outputter.log_container_finish(result: mock_result)
    end
  end

  describe '#log_message' do
    it 'sends message at the specified log level' do
      expect(mock_logger).to receive(:info).with('test message')
      outputter.log_message(level: :info, message: 'test message')
    end

    it 'works with warn level' do
      expect(mock_logger).to receive(:warn).with('warning')
      outputter.log_message(level: :warn, message: 'warning')
    end
  end
end
