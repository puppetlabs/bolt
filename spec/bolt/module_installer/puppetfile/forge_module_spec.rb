# frozen_string_literal: true

require 'bolt/module_installer/puppetfile/forge_module'

describe Bolt::ModuleInstaller::Puppetfile::ForgeModule do
  let(:name)    { 'puppetlabs/yaml' }
  let(:version) { '0.1.0' }
  let(:mod)     { described_class.new(name, version) }

  context '#initialize' do
    it 'converts version to a Semantic Puppet version' do
      expect(mod.version).to be_a(SemanticPuppet::Version)
    end

    it 'returns nil when there is no version' do
      mod = described_class.new(name, nil)
      expect(mod.version).to be(nil)
    end

    it 'returns nil when version is :latest' do
      mod = described_class.new(name, :latest)
      expect(mod.version).to be(nil)
    end

    it 'errors with invalid version' do
      expect { described_class.new(name, '>= 0.1.0') }.to raise_error(
        Bolt::ValidationError,
        /Invalid version for Forge module/
      )
    end
  end

  context '#to_spec' do
    it 'returns a Puppetfile spec' do
      expect(mod.to_spec).to eq("mod '#{name}', '#{version}'")
    end
  end

  context '#to_hash' do
    it 'returns a hash with the module attributes' do
      expect(mod.to_hash).to eq(
        'name'                => name,
        'version_requirement' => version
      )
    end
  end
end
