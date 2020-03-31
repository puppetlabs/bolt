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

  context "#resolve_reference" do
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
      expect(plugin.resolve_reference('query' => ""))
        .to eq([{ "uri" => certname }])
    end

    context "with a 'name' configured" do
      let(:opts) do
        { "query" => '',
          "target_mapping" => { "name" => 'facts.name_fact' } }
      end

      it "sets the uri to the specified name" do
        expect(plugin.resolve_reference(opts))
          .to eq([{ "name" => "thefakeslimcertname" }])
      end
    end

    context "with a 'alias' configured" do
      let(:opts) do
        { "query" => '',
          "target_mapping" => { "alias" => 'facts.hostname' } }
      end
      let(:values_hash) do
        { certname => [{
          'path' => ['hostname'],
          'value' => 'thereal'
        }] }
      end

      it "sets the alias to the fact value" do
        expect(plugin.resolve_reference(opts))
          .to eq([{ "uri" => certname,
                    "alias" => "thereal" }])
      end
    end

    context "with a 'config' configured" do
      let(:opts) do
        {
          "query" => '',
          "target_mapping" => {
            "config" => {
              "ssh" => { "host" => "facts.ipaddress" }
            }
          }
        }
      end
      let(:values_hash) do
        { certname => [{
          'path' => ['ipaddress'],
          'value' => '192.168.1.33'
        }] }
      end

      it "sets the ssh hostname to the fact value" do
        expect(plugin.resolve_reference(opts))
          .to eq([{ "uri" => certname,
                    "config" => { "ssh" => { "host" => "192.168.1.33" } } }])
      end
    end

    context "with a 'facts' configured" do
      let(:opts) do
        {
          "query" => '',
          "target_mapping" => {
            "facts" => {
              "myboltfact" => "facts.custom_fact"
            }
          }
        }
      end
      let(:values_hash) do
        { certname => [{
          'path' => ['custom_fact'],
          'value' => 'abc123'
        }] }
      end

      it "sets the target's fact to the fact value" do
        expect(plugin.resolve_reference(opts))
          .to eq([{ "uri" => certname,
                    "facts" => { "myboltfact" => "abc123" } }])
      end
    end

    context "with a 'features' configured" do
      let(:opts) do
        {
          "query" => '',
          "target_mapping" => {
            "features" => [
              "facts.custom_feature"
            ]
          }
        }
      end
      let(:values_hash) do
        { certname => [{
          'path' => ['custom_feature'],
          'value' => 'powershell'
        }] }
      end

      it "sets the target's feature to the fact value" do
        expect(plugin.resolve_reference(opts))
          .to eq([{ "uri" => certname,
                    "features" => ["powershell"] }])
      end
    end

    context "with a 'vars' configured" do
      let(:opts) do
        {
          "query" => '',
          "target_mapping" => {
            "vars" => { "puppetversion" => "facts.puppetversion" }
          }
        }
      end
      let(:values_hash) do
        { certname => [{
          'path' => ['puppetversion'],
          'value' => '6.13.0'
        }] }
      end

      it "sets the var to the fact value" do
        expect(plugin.resolve_reference(opts))
          .to eq([{ "uri" => certname,
                    "vars" => { "puppetversion" => "6.13.0" } }])
      end
    end

    context "when using 'certname' as a facts path" do
      let(:opts) do
        { "query" => '',
          "target_mapping" => { "name" => 'certname' } }
      end

      it "sets the name to the certname" do
        expect(plugin.resolve_reference(opts))
          .to eq([{ "name" => "therealslimcertname" }])
      end
    end

    context "with misplaced config keys" do
      let(:opts) do
        { "query" => '',
          "name" => 'facts.name_fact' }
      end

      it "raises a validation error" do
        expect { plugin.resolve_reference(opts) }
          .to raise_error(/PuppetDB plugin expects keys \["name"\]/)
      end
    end

    context "with unknown keys" do
      let(:opts) do
        { "query" => '',
          "target_mapping" => {},
          "bad_key" => '' }
      end

      it "raises a validation error" do
        expect { plugin.resolve_reference(opts) }
          .to raise_error(/Unknown keys in PuppetDB plugin: \["bad_key"\]/)
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

    context "with 'certname' as fact path" do
      let(:certname) { 'hostname.domain.tld' }
      let(:config) do
        { 'name' => 'certname' }
      end

      context " with no fact_values" do
        let(:data) { nil }

        it "returns the certname" do
          expect(plugin.resolve_facts(config, certname, data))
            .to eq({ 'name' => 'hostname.domain.tld' })
        end
      end

      context " with fact_values" do
        let(:data) do
          { certname => [{
            'path' => [1],
            'value' => 'the loneliest number'
          }] }
        end

        it "returns the certname" do
          expect(plugin.resolve_facts(config, certname, data))
            .to eq({ 'name' => 'hostname.domain.tld' })
        end
      end
    end

    context "with no fact_values" do
      it "returns an empty hash" do
        expect(plugin.resolve_facts({}, 'shady', nil)).to eq({})
      end
    end
  end
end
