# frozen_string_literal: true

require 'spec_helper'
require 'bolt/plugin/puppetdb'

describe Bolt::Plugin::Puppetdb do
  let(:config) do
    Bolt::PuppetDB::Config.new('server_urls' => 'https://localhost:8081',
                               'cacert' => '/path/to/cacert',
                               'token' => 'token')
  end
  let(:pdb_client) { Bolt::PuppetDB::Client.new(config) }
  let(:plugin) { Bolt::Plugin::Puppetdb.new(pdb_client) }
  let(:opts) do
  end

  it 'has a hook for inventory_targets' do
    expect(plugin.hooks).to eq(['inventory_targets'])
  end

  context "#fact_path" do
    it "converts a valid dot-notation fact to an array" do
      expect(plugin.fact_path("facts.straw.berries")).to eq(%w[straw berries])
    end

    it "errors when fact is not prepended with 'facts'" do
      expect { plugin.fact_path("strawberries") }
        .to raise_error(Bolt::Plugin::Puppetdb::FactLookupError,
                        /must start with 'facts.'/)
    end

    it "allows for 'certname'" do
      expect(plugin.fact_path("certname")).to eq(['certname'])
    end
  end

  context "#inventory_targets" do
    let(:certname) { 'therealslimcertname' }
    let(:name_fact) { 'thefakeslimcertname' }
    let(:values_hash) do
      { certname => [{
        'path' => ['name_fact'],
        'value' => name_fact
      }] }
    end
    before(:each) do
      allow(pdb_client).to receive(:query_certnames).and_return([certname])
      allow(pdb_client).to receive(:fact_values).and_return(values_hash)
    end

    it "sets uri to certname if uri and name are not configured" do
      expect(plugin.inventory_targets('query' => ""))
        .to eq([{ "uri" => certname }])
    end

    context "with a name configured" do
      let(:opts) do
        { "query" => '',
          "name" => 'facts.name_fact' }
      end

      it "sets the uri to the specified name" do
        expect(plugin.inventory_targets(opts))
          .to eq([{ "name" => "thefakeslimcertname" }])
      end
    end
  end

  context "#resolve_facts" do
    context "with invalid fact values" do
      let(:certname) { 'shady' }
      let(:config) { { 'name' => 1 } }
      let(:data) do
        { certname => [{
          'path' => [1],
          'value' => 'the loneliest number'
        }] }
      end

      it "raises an error" do
        expect { plugin.resolve_facts(config, certname, data) }
          .to raise_error(Bolt::Plugin::Puppetdb::FactLookupError, /be a string/)
      end
    end

    context "with no fact_values" do
      it "returns an empty hash" do
        expect(plugin.resolve_facts({}, 'shady', nil)).to eq({})
      end
    end
  end
end
