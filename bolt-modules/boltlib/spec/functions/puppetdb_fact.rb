# frozen_string_literal: true

require 'spec_helper'

describe 'puppetdb_fact' do
  include PuppetlabsSpec::Fixtures

  let(:executor) { mock('bolt_executor') }
  let(:inventory) { mock('inventory') }

  around(:each) do |example|
    Puppet[:tasks] = true
    Puppet.features.stubs(:bolt?).returns(true)

    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      example.run
    end
  end

  context 'it calls puppetdb_facts' do
    let(:targets) { %w[a.com b.com] }
    let(:pdb_facts) { { 'a.com' => {}, 'b.com' => {} } }
    it 'with list of nodes' do
      executor.expects(:puppetdb_facts).with(targets).returns(pdb_facts)

      is_expected.to run.with_params(targets).and_return(pdb_facts)
    end
  end
end
