# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/plans/mock_executor'
require 'bolt/executor'

describe BoltSpec::Plans::MockExecutor do
  it 'defines all public methods on Bolt::Executor' do
    missing_methods = Bolt::Executor.instance_methods - described_class.instance_methods
    message = "#{described_class} is missing definitions for public methods #{missing_methods.join(', ')}"

    expect(missing_methods.empty?).to be(true), message
  end

  context '#module_file_id' do
    let(:executor) { BoltSpec::Plans::MockExecutor.new('/some/path/to/modules') }

    it 'returns nil if path is outside of modulepath' do
      expect(executor.module_file_id('/some/other/path')).to be_nil
    end

    it 'handles module relative paths relative to module/files returning module/path excluding the files dir' do
      expect(executor.module_file_id('/some/path/to/modules/amodule/files/dingo')).to eq('amodule/dingo')
    end

    it 'handles module relative paths outside of module/files' do
      expect(executor.module_file_id('/some/path/to/modules/amodule/files/../other/dingo')).to eq('amodule/other/dingo')
    end
  end
end
