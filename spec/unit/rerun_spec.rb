# frozen_string_literal: true

require 'spec_helper'
require 'bolt/rerun'
require 'bolt/result'
require 'bolt/result_set'
require 'bolt/plan_result'
require 'bolt/error'
require 'bolt/inventory'

describe Bolt::Rerun do
  let(:tmpdir)      { Dir.mktmpdir }
  let(:rerun_path)  { File.join(tmpdir, '.rerun.json') }
  let(:rerun)       { described_class.new(rerun_path, true) }

  after(:each) { FileUtils.rm_rf(tmpdir) }

  let(:valid_data) do
    [
      { 'target' => 'host1', 'status' => 'success' },
      { 'target' => 'host2', 'status' => 'failure' }
    ]
  end

  before(:each) do
    File.write(rerun_path, valid_data.to_json)
  end

  describe '#data' do
    it 'reads and returns rerun data' do
      expect(rerun.data).to eq(valid_data)
    end

    it 'raises FileError when data is missing required fields' do
      File.write(rerun_path, [{ 'target' => 'host1' }].to_json)
      expect { rerun.data }.to raise_error(Bolt::FileError, /Missing data/)
    end

    it 'raises FileError when data is not an array' do
      File.write(rerun_path, '{}')
      expect { rerun.data }.to raise_error(Bolt::FileError)
    end
  end

  describe '#get_targets' do
    it 'returns all targets for filter all' do
      expect(rerun.get_targets('all')).to contain_exactly('host1', 'host2')
    end

    it 'returns only failed targets for filter failure' do
      expect(rerun.get_targets('failure')).to eq(['host2'])
    end

    it 'returns only successful targets for filter success' do
      expect(rerun.get_targets('success')).to eq(['host1'])
    end

    it 'raises CLIError for unknown filter' do
      expect { rerun.get_targets('unknown') }
        .to raise_error(Bolt::CLIError, /Unexpected option/)
    end
  end

  describe '#update' do
    let(:target1) { Bolt::Inventory.empty.get_target('host1') }
    let(:target2) { Bolt::Inventory.empty.get_target('host2') }

    it 'writes result set to file' do
      result1 = Bolt::Result.new(target1, message: 'ok', action: 'run')
      result2 = Bolt::Result.new(target2, error: { 'msg' => 'oops', 'kind' => 'err', 'details' => {} }, action: 'run')
      rs = Bolt::ResultSet.new([result1, result2])
      rerun.update(rs)
      data = JSON.parse(File.read(rerun_path))
      expect(data.map { |d| d['target'] }).to contain_exactly('host1', 'host2')
    end

    it 'does nothing when save_failures is false' do
      rerun_no_save = described_class.new(rerun_path, false)
      original_content = File.read(rerun_path)
      rerun_no_save.update(Bolt::ResultSet.new([]))
      expect(File.read(rerun_path)).to eq(original_content)
    end

    it 'removes the file when result is not a ResultSet or PlanResult' do
      rerun.update('some string')
      expect(File.exist?(rerun_path)).to be false
    end

    it 'handles PlanResult wrapping a ResultSet' do
      result = Bolt::Result.new(target1, message: 'ok', action: 'run')
      rs = Bolt::ResultSet.new([result])
      plan_result = Bolt::PlanResult.new(rs, 'success')
      rerun.update(plan_result)
      data = JSON.parse(File.read(rerun_path))
      expect(data.first['target']).to eq('host1')
    end

    it 'handles PlanResult wrapping a RunFailure' do
      result = Bolt::Result.new(target1, error: { 'msg' => 'oops', 'kind' => 'err', 'details' => {} }, action: 'run')
      rs = Bolt::ResultSet.new([result])
      run_failure = Bolt::RunFailure.new(rs, 'run', 'mytask')
      plan_result = Bolt::PlanResult.new(run_failure, 'failure')
      rerun.update(plan_result)
      data = JSON.parse(File.read(rerun_path))
      expect(data.first['target']).to eq('host1')
    end

    it 'logs warning on write failure' do
      result = Bolt::Result.new(target1, message: 'ok', action: 'run')
      rs = Bolt::ResultSet.new([result])
      allow(File).to receive(:write).and_raise(Errno::EACCES, 'permission denied')
      expect(Bolt::Logger).to receive(:warn_once)
      rerun.update(rs)
    end
  end
end
