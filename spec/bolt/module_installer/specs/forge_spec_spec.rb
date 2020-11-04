# frozen_string_literal: true

require 'spec_helper'
require 'bolt/module_installer/specs/forge_spec'

describe Bolt::ModuleInstaller::Specs::ForgeSpec do
  let(:name)                { 'puppetlabs/yaml' }
  let(:version_requirement) { '>= 0.1.0' }
  let(:init_hash)           { { 'name' => name, 'version_requirement' => version_requirement } }
  let(:spec)                { described_class.new(init_hash) }

  context '#initialize' do
    it 'normalizes the full name' do
      init_hash['name'] = 'puppetlabs-yaml'
      expect(spec.full_name).to eq(name)
    end

    it 'extracts the module name' do
      expect(spec.name).to eq('yaml')
    end

    it 'allows uppercase letters for owner' do
      init_hash['name'] = 'Puppetlabs/yaml'
      expect { spec }.not_to raise_error
    end

    it 'errors with an invalid name' do
      init_hash['name'] = 'yaml'
      expect { spec }.to raise_error(
        Bolt::ValidationError,
        /Invalid name for Forge module/
      )
    end

    it 'errors with an invalid owner' do
      init_hash['name'] = 'puppet_labs/yaml'
      expect { spec }.to raise_error(
        Bolt::ValidationError,
        /Invalid name for Forge module/
      )
    end

    it 'converts version requirement to a Semantic Puppet version range' do
      expect(spec.semantic_version).to be_a(SemanticPuppet::VersionRange)
    end

    it 'sets semantic version requirement to >= 0 when version requirement is not given' do
      init_hash.delete('version_requirement')
      expect(spec.semantic_version.to_s).to be('>= 0')
    end

    it 'errors with invalid version requirement' do
      init_hash['version_requirement'] = 'foo'
      expect { spec }.to raise_error(
        Bolt::ValidationError,
        /Invalid version requirement for Forge module specification/
      )
    end
  end

  context '#implements?' do
    it 'returns true if the hash implements the class' do
      hash = {
        'name'                => name,
        'version_requirement' => version_requirement
      }

      expect(described_class.implements?(hash)).to be(true)
    end

    it 'returns false if the hash implements the class' do
      hash = {
        'name'    => name,
        'version' => version_requirement
      }

      expect(described_class.implements?(hash)).to be(false)
    end
  end

  context '#to_hash' do
    it 'returns a hash with the name and version requirement' do
      expect(spec.to_hash).to eq(
        'name'                => name,
        'version_requirement' => version_requirement
      )
    end

    it 'returns a hash with just the name' do
      init_hash.delete('version_requirement')

      expect(spec.to_hash).to eq(
        'name' => name
      )
    end
  end

  context '#to_resolver_module' do
    it 'returns a puppetfile-resolver module object' do
      expect(spec.to_resolver_module).to be_a(PuppetfileResolver::Puppetfile::ForgeModule)
    end
  end

  context '#satisfied_by?' do
    it 'returns true if module satisfies' do
      version = SemanticPuppet::Version.parse('0.1.0')
      mod     = double('mod', type: :forge, full_name: name, version: version)

      expect(spec.satisfied_by?(mod)).to be(true)
    end

    it 'returns false if module does not satisfy' do
      version = SemanticPuppet::Version.parse('0.0.0')
      mod     = double('mod', type: :forge, full_name: name, version: version)

      expect(spec.satisfied_by?(mod)).to be(false)
    end

    it 'is case insensitive when comparing names' do
      version = SemanticPuppet::Version.parse('0.1.0')
      mod     = double('mod', type: :forge, full_name: name.upcase, version: version)

      expect(spec.satisfied_by?(mod)).to be(true)
    end
  end
end
