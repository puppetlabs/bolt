# frozen_string_literal: true

require 'spec_helper'
require 'bolt/apply_result'
require 'bolt/target'

describe Bolt::ApplyResult do
  describe '#puppet_missing_error' do
    it 'returns the nil if no identifiable errors are found' do
      result = Bolt::Result.for_task(:target, '', 'blah', 1, 'catalog')
      expect(Bolt::ApplyResult.puppet_missing_error(result)).to be_nil
    end

    it 'returns nil if no errors are present' do
      result = Bolt::Result.for_task(:target, 'hello', '', 0, 'catalog')
      expect(Bolt::ApplyResult.puppet_missing_error(result)).to be_nil
    end

    it 'errors if /opt/puppetlabs/puppet/bin/ruby not found on Linux' do
      orig_result = Bolt::Result.for_task(:target, '', 'blah', 127, 'catalog')
      error = Bolt::ApplyResult.puppet_missing_error(orig_result)
      expect(error['kind']).to eq('bolt/apply-error')
      expect(error['msg'])
        .to eq("Puppet is not installed on the target, please install it to enable 'apply'")
    end

    it 'errors if /opt/puppetlabs/puppet/bin/ruby not found on macOS' do
      orig_result = Bolt::Result.for_task(:target, '', 'blah', 126, 'catalog')
      error = Bolt::ApplyResult.puppet_missing_error(orig_result)
      expect(error['kind']).to eq('bolt/apply-error')
      expect(error['msg'])
        .to eq("Puppet is not installed on the target, please install it to enable 'apply'")
    end

    it 'errors if Ruby cannot be found on Windows' do
      orig_result = Bolt::Result.for_task(:target, '', "Could not find executable 'ruby.exe'", 1, 'catalog')
      error = Bolt::ApplyResult.puppet_missing_error(orig_result)
      expect(error['kind']).to eq('bolt/apply-error')
      expect(error['msg'])
        .to eq("Puppet is not installed on the target in $env:ProgramFiles, please install it to enable 'apply'")
    end

    it 'errors if Puppet cannot be found on Windows' do
      orig_result = Bolt::Result.for_task(:target, '', 'cannot load such file -- puppet (LoadError)', 1, 'catalog')
      error = Bolt::ApplyResult.puppet_missing_error(orig_result)
      expect(error['kind']).to eq('bolt/apply-error')
      expect(error['msg'])
        .to eq('Found a Ruby without Puppet present, please install Puppet ' \
              "or remove Ruby from $env:Path to enable 'apply'")
    end
  end

  describe 'type and object' do
    it 'exposes apply as the type' do
      result = Bolt::Result.for_task(:target, 'hello', '', 0, 'catalog')
      result = Bolt::ApplyResult.new(result)
      expect(result.type).to be('apply')
      expect(result.object).to be(nil)
    end
  end
end
