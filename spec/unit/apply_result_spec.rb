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
