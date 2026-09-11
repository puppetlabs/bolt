# frozen_string_literal: true

require 'spec_helper'
require 'bolt/plugin'
require 'bolt/plugin/task'
require 'bolt/error'

describe Bolt::Plugin::Task do
  let(:context) { double('context') }
  let(:plugin) { described_class.new(context: context) }

  describe '#name' do
    it 'returns "task"' do
      expect(plugin.name).to eq('task')
    end
  end

  describe '#hooks' do
    it 'returns the expected hook names' do
      expect(plugin.hooks).to contain_exactly(:puppet_library, :resolve_reference, :validate_resolve_reference)
    end
  end

  describe '#hook_descriptions' do
    it 'returns a hash of hook descriptions' do
      descs = plugin.hook_descriptions
      expect(descs).to be_a(Hash)
      expect(descs[:resolve_reference]).to match(/plugin/)
      expect(descs[:puppet_library]).to match(/puppet/i)
    end
  end

  describe '#validate_options' do
    it 'raises ValidationError when task is not specified' do
      expect { plugin.validate_options({}) }
        .to raise_error(Bolt::ValidationError, /task.*specified/)
    end

    it 'calls get_validated_task when task is specified' do
      expect(context).to receive(:get_validated_task).with('mytask', {}).and_return(double('task'))
      plugin.validate_options('task' => 'mytask')
    end

    it 'passes parameters to get_validated_task' do
      params = { 'param1' => 'val1' }
      expect(context).to receive(:get_validated_task).with('mytask', params).and_return(double('task'))
      plugin.validate_options('task' => 'mytask', 'parameters' => params)
    end
  end

  describe '#run_task' do
    it 'raises ValidationError when task is not specified' do
      expect { plugin.run_task({}) }
        .to raise_error(Bolt::ValidationError, /task.*specified/)
    end

    it 'raises Bolt::Error when result has an error_hash' do
      task = double('task')
      result = double('result', error_hash: { 'msg' => 'failed', 'kind' => 'bolt/error' }, value: {})
      allow(context).to receive(:get_validated_task).and_return(task)
      allow(context).to receive(:run_local_task).and_return([result])

      expect { plugin.run_task('task' => 'mytask') }
        .to raise_error(Bolt::Error, /failed/)
    end

    it 'returns result when successful' do
      task = double('task')
      result = double('result', error_hash: nil, value: { 'key' => 'val' })
      allow(context).to receive(:get_validated_task).and_return(task)
      allow(context).to receive(:run_local_task).and_return([result])

      expect(plugin.run_task('task' => 'mytask')).to eq(result)
    end
  end

  describe '#resolve_reference' do
    it 'raises ValidationError when result does not include "value" key' do
      task = double('task')
      result = double('result', error_hash: nil, value: { 'other' => 'data' }, :[] => nil)
      allow(context).to receive(:get_validated_task).and_return(task)
      allow(context).to receive(:run_local_task).and_return([result])

      expect { plugin.resolve_reference('task' => 'mytask') }
        .to raise_error(Bolt::ValidationError, /did not return 'value'/)
    end

    it 'returns the value from the result' do
      task = double('task')
      result = double('result', error_hash: nil, value: { 'value' => 'myvalue' })
      allow(result).to receive(:[]).with('value').and_return('myvalue')
      allow(context).to receive(:get_validated_task).and_return(task)
      allow(context).to receive(:run_local_task).and_return([result])

      expect(plugin.resolve_reference('task' => 'mytask')).to eq('myvalue')
    end
  end

  describe '#puppet_library' do
    let(:target) { double('target') }
    let(:apply_prep) { double('apply_prep') }

    it 'raises PluginError when task cannot be found' do
      bolt_error = Bolt::Error.new('task not found', 'bolt/error')
      allow(context).to receive(:get_validated_task).and_raise(bolt_error)

      expect { plugin.puppet_library({ 'task' => 'missing_task' }, target, apply_prep) }
        .to raise_error(Bolt::Plugin::PluginError::ExecutionError)
    end

    it 'returns a proc that runs the task on the target' do
      task = double('task')
      result = double('result')
      params = { 'param1' => 'val' }
      allow(context).to receive(:get_validated_task).with('mytask', params).and_return(task)
      allow(apply_prep).to receive(:run_task).with([target], task, params, {}).and_return([result])

      proc = plugin.puppet_library({ 'task' => 'mytask', 'parameters' => params }, target, apply_prep)
      expect(proc).to be_a(Proc)
      expect(proc.call).to eq(result)
    end

    it 'passes _run_as in run options when specified' do
      task = double('task')
      result = double('result')
      allow(context).to receive(:get_validated_task).and_return(task)
      allow(apply_prep).to receive(:run_task).with([target], task, {}, { run_as: 'root' }).and_return([result])

      proc = plugin.puppet_library({ 'task' => 'mytask', '_run_as' => 'root' }, target, apply_prep)
      proc.call
    end
  end
end
