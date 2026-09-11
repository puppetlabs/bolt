# frozen_string_literal: true

require 'spec_helper'
require 'bolt/apply_result'
require 'bolt/target'

describe Bolt::ApplyResult do
  let(:example_target) { Bolt::Target.new('target') }
  let(:result_value) {
    { "metrics" => {},
      "resource_statuses" => {},
      "status" => "" }
  }

  let(:catalog)      { {} }
  let(:task_result)  { Bolt::Result.for_task(example_target, result_value.to_json, '', 0, 'catalog', []) }
  let(:apply_result) { Bolt::ApplyResult.from_task_result(task_result, catalog) }

  describe '#puppet_missing_error' do
    it 'returns the nil if no identifiable errors are found' do
      result = Bolt::Result.for_task(:target, '', 'blah', 1, 'catalog', [])
      expect(Bolt::ApplyResult.puppet_missing_error(result)).to be_nil
    end

    it 'returns nil if no errors are present' do
      result = Bolt::Result.for_task(:target, 'hello', '', 0, 'catalog', [])
      expect(Bolt::ApplyResult.puppet_missing_error(result)).to be_nil
    end

    it 'errors if /opt/puppetlabs/puppet/bin/ruby not found on Linux' do
      orig_result = Bolt::Result.for_task(:target, '', 'blah', 127, 'catalog', [])
      error = Bolt::ApplyResult.puppet_missing_error(orig_result)
      expect(error['kind']).to eq('bolt/apply-error')
      expect(error['msg'])
        .to eq("Puppet is not installed on the target, please install it to enable 'apply'")
    end

    it 'errors if /opt/puppetlabs/puppet/bin/ruby not found on macOS' do
      orig_result = Bolt::Result.for_task(:target, '', 'blah', 126, 'catalog', [])
      error = Bolt::ApplyResult.puppet_missing_error(orig_result)
      expect(error['kind']).to eq('bolt/apply-error')
      expect(error['msg'])
        .to eq("Puppet is not installed on the target, please install it to enable 'apply'")
    end

    it 'errors if Ruby cannot be found on Windows' do
      orig_result = Bolt::Result.for_task(:target, '', "Could not find executable 'ruby.exe'", 1, 'catalog', [])
      error = Bolt::ApplyResult.puppet_missing_error(orig_result)
      expect(error['kind']).to eq('bolt/apply-error')
      expect(error['msg'])
        .to eq("Puppet was not found on the target or in $env:ProgramFiles, please install it to enable 'apply'")
    end

    it 'errors if Puppet cannot be found on Windows' do
      orig_result = Bolt::Result.for_task(:target, '', 'cannot load such file -- puppet (LoadError)', 1, 'catalog', [])
      error = Bolt::ApplyResult.puppet_missing_error(orig_result)
      expect(error['kind']).to eq('bolt/apply-error')
      expect(error['msg'])
        .to eq('Found a Ruby without Puppet present, please install Puppet ' \
              "or remove Ruby from $env:Path to enable 'apply'")
    end
  end

  describe :from_task_result do
    context 'with an unparseable result' do
      let(:result_value) { 'oops' }
      it 'generates an error when keys are missing' do
        expect(apply_result.ok).to eq(false)
        expect(apply_result['_error']['kind']).to eq('bolt/invalid-report')
      end
    end

    context 'with missing keys' do
      let(:result_value) { {} }
      it 'generates an error when keys are missing' do
        expect(apply_result.ok).to eq(false)
        expect(apply_result['_error']['kind']).to eq('bolt/invalid-report')
      end
    end
  end

  describe 'action and object' do
    it 'exposes apply as the action' do
      expect(apply_result.action).to be('apply')
      expect(apply_result.object).to be(nil)
    end
  end

  describe '#resource_error' do
    it 'returns nil when status is not failed' do
      result = Bolt::Result.for_task(example_target, result_value.to_json, '', 0, 'catalog', [])
      expect(Bolt::ApplyResult.resource_error(result)).to be_nil
    end

    it 'returns an error hash when resources failed' do
      value = {
        'status' => 'failed',
        'resource_statuses' => {
          'File[/tmp/foo]' => {
            'failed' => true,
            'events' => [{ 'status' => 'failure', 'message' => 'permission denied' }]
          }
        }
      }
      result = Bolt::Result.for_task(example_target, value.to_json, '', 0, 'catalog', [])
      error = Bolt::ApplyResult.resource_error(result)
      expect(error['kind']).to eq('bolt/resource-failure')
      expect(error['msg']).to match(/permission denied/)
    end
  end

  describe '#invalid_report_error' do
    it 'returns nil when all expected keys are present' do
      result = Bolt::Result.for_task(example_target, result_value.to_json, '', 0, 'catalog', [])
      expect(Bolt::ApplyResult.invalid_report_error(result)).to be_nil
    end

    it 'returns an error with _output message when _output key is present' do
      value = { '_output' => 'something printed to stdout' }
      result = Bolt::Result.for_task(example_target, value.to_json, '', 0, 'catalog', [])
      error = Bolt::ApplyResult.invalid_report_error(result)
      expect(error['kind']).to eq('bolt/invalid-report')
      expect(error['msg']).to match(/_output/)
    end

    it 'returns an error listing missing keys when no _output key' do
      value = { 'status' => 'success' }
      result = Bolt::Result.for_task(example_target, value.to_json, '', 0, 'catalog', [])
      error = Bolt::ApplyResult.invalid_report_error(result)
      expect(error['kind']).to eq('bolt/invalid-report')
      expect(error['msg']).to match(/missing/)
    end
  end

  describe '#from_task_result' do
    it 'creates a successful ApplyResult from a valid task result' do
      value = {
        'metrics' => { 'resources' => { 'values' => [['changed', nil, 0], ['failed', nil, 0],
                                                     ['skipped', nil, 0], ['total', nil, 0],
                                                     ['out_of_sync', nil, 0]] } },
        'resource_statuses' => {},
        'status' => 'unchanged',
        'logs' => []
      }
      result = Bolt::Result.for_task(example_target, value.to_json, '', 0, 'catalog', [])
      apply = Bolt::ApplyResult.from_task_result(result)
      expect(apply.ok?).to be true
    end

    it 'creates a failed ApplyResult when the task result has resource failures' do
      value = {
        'metrics' => {},
        'resource_statuses' => {
          'File[/tmp/x]' => {
            'failed' => true,
            'events' => [{ 'status' => 'failure', 'message' => 'oops' }]
          }
        },
        'status' => 'failed',
        'logs' => []
      }
      result = Bolt::Result.for_task(example_target, value.to_json, '', 0, 'catalog', [])
      apply = Bolt::ApplyResult.from_task_result(result)
      expect(apply.ok?).to be false
      expect(apply.error_hash['kind']).to eq('bolt/resource-failure')
    end

    it 'creates a failed ApplyResult from a non-ok task result' do
      result = Bolt::Result.for_task(example_target, '{}', '', 1, 'catalog', [])
      apply = Bolt::ApplyResult.from_task_result(result)
      expect(apply.ok?).to be false
    end
  end

  describe '#event_metrics' do
    it 'returns nil when report has no metrics' do
      result = Bolt::ApplyResult.new(example_target, report: {})
      expect(result.event_metrics).to be_nil
    end

    it 'returns a hash of metric name to value' do
      report = {
        'metrics' => {
          'resources' => {
            'values' => [
              ['changed', nil, 3], ['failed', nil, 1], ['skipped', nil, 0],
              ['total', nil, 4], ['out_of_sync', nil, 4]
            ]
          }
        }
      }
      result = Bolt::ApplyResult.new(example_target, report: report)
      expect(result.event_metrics).to include('changed' => 3, 'failed' => 1)
    end
  end

  describe '#logs' do
    it 'returns an empty array when the report has no logs' do
      result = Bolt::ApplyResult.new(example_target, report: {})
      expect(result.logs).to eq([])
    end

    it 'returns the log entries from the report' do
      report = { 'logs' => [{ 'level' => 'warn', 'message' => 'oops', 'source' => 'Puppet' }] }
      result = Bolt::ApplyResult.new(example_target, report: report)
      expect(result.logs).to eq(report['logs'])
    end
  end

  describe '#resource_logs' do
    it 'excludes logs with source == Puppet' do
      report = {
        'logs' => [
          { 'level' => 'warn', 'message' => 'puppet msg', 'source' => 'Puppet' },
          { 'level' => 'warn', 'message' => 'resource msg', 'source' => 'File[/tmp/x]' }
        ]
      }
      result = Bolt::ApplyResult.new(example_target, report: report)
      expect(result.resource_logs.length).to eq(1)
      expect(result.resource_logs.first['source']).to eq('File[/tmp/x]')
    end
  end

  describe '#metrics_message' do
    it 'returns nil when there are no event metrics' do
      result = Bolt::ApplyResult.new(example_target)
      expect(result.metrics_message).to be_nil
    end

    it 'returns a summary string when metrics are present' do
      report = {
        'metrics' => {
          'resources' => {
            'values' => [
              ['changed', nil, 2], ['failed', nil, 1], ['skipped', nil, 0],
              ['total', nil, 5], ['out_of_sync', nil, 3]
            ]
          }
        }
      }
      result = Bolt::ApplyResult.new(example_target, report: report)
      expect(result.metrics_message).to match(/changed: 2.*failed: 1/m)
    end
  end

  describe '#report' do
    it 'returns the report from the value hash' do
      report = { 'logs' => [] }
      result = Bolt::ApplyResult.new(example_target, report: report)
      expect(result.report).to eq(report)
    end

    it 'returns nil when no report is set' do
      result = Bolt::ApplyResult.new(example_target)
      expect(result.report).to be_nil
    end
  end

  describe '#generic_value' do
    it 'returns an empty hash' do
      expect(apply_result.generic_value).to eq({})
    end
  end

  describe 'exposes methods for examining data' do
    let(:partial) do
      { "target" => "target",
        "action" => "apply",
        "object" => nil,
        "status" => "success" }
    end

    it 'with to_json' do
      result = JSON.parse(apply_result.to_json)
      expect(result).to include(partial)
      expect(result['value']).to eq('report' => result_value, '_sensitive' => "Sensitive [value redacted]")
    end

    it 'with to_data' do
      result = apply_result.to_data
      expect(result).to include(partial)
      expect(result['value']).to eq('report' => result_value, '_sensitive' => "Sensitive [value redacted]")
    end

    it 'with value' do
      expect(apply_result.value).to include('report' => result_value)
      expect(apply_result.value['_sensitive']).to be_a(Puppet::Pops::Types::PSensitiveType::Sensitive)
      expect(apply_result.value['_sensitive'].unwrap).to eq('catalog' => catalog)
    end

    it 'with catalog' do
      expect(apply_result.catalog).to eq(catalog)
    end
  end
end
