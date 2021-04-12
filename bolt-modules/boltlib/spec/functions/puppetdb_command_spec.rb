# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'

describe 'puppetdb_command' do
  include PuppetlabsSpec::Fixtures

  let(:executor)   { Bolt::Executor.new }
  let(:pdb_client) { mock('pdb_client') }
  let(:tasks)      { true }

  let(:command) { 'replace_facts' }
  let(:payload) { {} }
  let(:version) { 5 }

  around(:each) do |example|
    Puppet[:tasks] = tasks
    Puppet.override(bolt_executor: executor, bolt_pdb_client: pdb_client) do
      example.run
    end
  end

  it 'calls Bolt::PuppetDB::Client.send_command' do
    pdb_client.expects(:send_command).with(command, version, payload).returns('uuid')
    is_expected.to run.with_params(command, version, payload)
  end

  it 'errors if client does not implement :send_command' do
    is_expected.to run
      .with_params(command, version, payload)
      .and_raise_error(/PuppetDB client .* does not implement :send_command/)
  end

  it 'reports the call to analytics' do
    pdb_client.expects(:send_command).returns('uuid')
    executor.expects(:report_function_call).with('puppetdb_command')
    is_expected.to run.with_params(command, version, payload)
  end

  context 'without tasks enabled' do
    let(:tasks) { false }

    it 'errors' do
      is_expected.to run
        .with_params(command, version, payload)
        .and_raise_error(/Plan language function 'puppetdb_command' cannot be used/)
    end
  end
end
