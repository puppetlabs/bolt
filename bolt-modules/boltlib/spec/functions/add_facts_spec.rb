# frozen_string_literal: true

require 'spec_helper'
require 'bolt/target'

describe 'add_facts' do
  include PuppetlabsSpec::Fixtures
  let(:executor) { mock('bolt_executor') }
  let(:inventory) { mock('inventory') }
  let(:target) { Bolt::Target.new('example') }

  around(:each) do |example|
    Puppet[:tasks] = true
    Puppet.features.stubs(:bolt?).returns(true)

    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      example.run
    end
  end

  it 'should set a fact on a target' do
    data = { 'a' => 'b', 'c' => 'd' }
    inventory.expects(:add_facts).with(target, data).returns(data)
    is_expected.to run.with_params(target, data).and_return(data)
  end

  it 'errors when passed invalid data types' do
    is_expected.to run.with_params(target, 1)
                      .and_raise_error(ArgumentError,
                                       "'add_facts' parameter 'facts' expects a Hash value, got Integer")
  end
end
