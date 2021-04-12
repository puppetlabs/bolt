# frozen_string_literal: true

require 'spec_helper'
require 'bolt/puppetdb/client'
require 'bolt_spec/puppetdb'
require 'bolt_spec/bolt_server'

describe Bolt::PuppetDB::Client, puppetdb: true do
  include BoltSpec::PuppetDB
  include BoltSpec::BoltServer

  let(:client) { pdb_client }

  # Don't run any tests until PDB and puppetserver are responsive
  before(:all) do
    wait_until_available(timeout: 30, interval: 1)
  end

  context '#send_command' do
    let(:command) { 'replace_facts' }
    let(:facts)   { { 'dog' => 'germanshepherd' } }
    let(:target)  { 'target.example.com' }
    let(:version) { 5 }

    let(:payload) do
      {
        'certname'           => target,
        'environment'        => 'dev',
        'producer'           => 'bolt',
        'producer_timestamp' => Time.now.strftime("%Y-%m-%d"),
        'values'             => facts
      }
    end

    it 'replaces facts' do
      expect { client.send_command(command, version, payload) }.not_to raise_error
      expect(client.facts_for_node([target])).to eq(target => facts)
    end

    it 'returns a UUID' do
      expect(client.send_command(command, version, payload)).to be_kind_of(String)
    end

    it 'errors without a certname' do
      payload.delete('certname')
      expect { client.send_command(command, version, payload) }.to raise_error(
        Bolt::Error,
        /Payload must include 'certname'/
      )
    end
  end
end
