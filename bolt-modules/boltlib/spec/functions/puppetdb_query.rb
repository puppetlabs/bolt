# frozen_string_literal: true

require 'spec_helper'

describe 'puppetdb_query' do
  include PuppetlabsSpec::Fixtures

  let(:pdb_client) { mock('pdb_client') }

  around(:each) do |example|
    Puppet[:tasks] = true
    Puppet.features.stubs(:bolt?).returns(true)

    Puppet.override(bolt_pdb_client: pdb_client) do
      example.run
    end
  end

  context 'it calls puppetdb_facts' do
    it 'with list of nodes' do
      query = 'inventory {}'
      result = [1, 2, 3]
      pdb_client.expects(:make_query).with(query).returns(result)

      is_expected.to run.with_params(query).and_return(result)
    end
  end
end
