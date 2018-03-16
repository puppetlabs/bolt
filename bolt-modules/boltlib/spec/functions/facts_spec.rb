# frozen_string_literal: true

require 'spec_helper'
require 'bolt/target'

describe 'facts' do
  include PuppetlabsSpec::Fixtures

  let(:executor) { mock('bolt_executor') }
  let(:inventory) { mock('inventory') }
  let(:hostname) { 'example' }
  let(:target) { Bolt::Target.new(hostname) }

  around(:each) do |example|
    Puppet[:tasks] = true
    Puppet.features.stubs(:bolt?).returns(true)

    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      example.run
    end
  end

  it 'should return an empty hash if no facts are set' do
    inventory.expects(:facts).with(target).returns({})
    is_expected.to run.with_params(target).and_return({})
  end
end
