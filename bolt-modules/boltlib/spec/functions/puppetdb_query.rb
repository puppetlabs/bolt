# frozen_string_literal: true

require 'spec_helper'

describe 'puppetdb_query' do
  include PuppetlabsSpec::Fixtures

  let(:pdb_client) { mock('pdb_client') }

  around(:each) do |example|
    Puppet[:tasks] = true
    Puppet.override(bolt_pdb_client: pdb_client) do
      example.run
    end
  end

  context 'it calls puppetdb_facts' do
    let(:query)    { 'inventory {}' }
    let(:result)   { [1, 2, 3] }
    let(:instance) { 'instance' }

    it 'with list of targets' do
      pdb_client.expects(:make_query).with(query).returns(result)

      is_expected.to run.with_params(query).and_return(result)
    end

    it 'with a named instance' do
      pdb_client.expects(:make_query).with(query, instance).returns(result)

      is_expected.to run.with_params(query, instance).and_return(result)
    end
  end
end
