# frozen_string_literal: true

require 'spec_helper'
require 'bolt/module_installer/specs/git_spec'

describe Bolt::ModuleInstaller::Specs::GitSpec do
  let(:name)      { 'yaml' }
  let(:git)       { 'https://github.com/puppetlabs/puppetlabs-yaml' }
  let(:ref)       { '0.1.0' }
  let(:init_hash) { { 'name' => name, 'git' => git, 'ref' => ref } }
  let(:spec)      { described_class.new(init_hash) }

  context '#initialize' do
    it 'extracts the module name' do
      init_hash['name'] = "puppetlabs-#{name}"
      expect(spec.name).to eq(name)
    end

    it 'allows uppercase letters for owner' do
      init_hash['name'] = 'Puppetlabs/yaml'
      expect { spec }.not_to raise_error
    end

    it 'errors with an invalid name' do
      init_hash['name'] = 'Yaml'
      expect { spec }.to raise_error(
        Bolt::ValidationError,
        /Invalid name for Git module specification/
      )
    end

    it 'errors with an invalid owner' do
      init_hash['name'] = 'puppet_labs/yaml'
      expect { spec }.to raise_error(
        Bolt::ValidationError,
        /Invalid name for Git module specification/
      )
    end

    it 'errors with invalid git source' do
      init_hash['git'] = 'gitlab.com/puppetlabs/puppetlabs-yaml'
      expect { spec }.to raise_error(
        Bolt::ValidationError,
        /Invalid URI #{init_hash['git']}/
      )
    end

    it 'errors if resolve is false and missing a name' do
      init_hash.delete('name')
      init_hash['resolve'] = false
      expect { spec }.to raise_error(
        Bolt::ValidationError,
        /Missing name.*when 'resolve' is false/
      )
    end

    it 'errors with non-Boolean resolve value' do
      init_hash['resolve'] = 'no'
      expect { spec }.to raise_error(
        Bolt::ValidationError,
        /Option 'resolve'.*must be a Boolean/
      )
    end
  end

  context '#to_hash' do
    it 'returns a hash with the git and ref' do
      expect(spec.to_hash).to eq(
        'git' => git,
        'ref' => ref
      )
    end
  end

  context '#implements?' do
    it 'returns true if the hash implements the class' do
      hash = {
        'git' => git,
        'ref' => ref
      }

      expect(described_class.implements?(hash)).to be(true)
    end

    it 'returns false if the hash does not implement the class' do
      hash = {
        'git' => git
      }

      expect(described_class.implements?(hash)).to be(false)
    end
  end

  context '#satisfied_by?' do
    it 'returns true when module satisfies' do
      mod = double('mod', type: :git, git: git)
      expect(spec.satisfied_by?(mod)).to be(true)
    end

    it 'returns false when module does not satisfy' do
      mod = double('mod', type: :git, git: 'foo')
      expect(spec.satisfied_by?(mod)).to be(false)
    end
  end

  context '#to_resolver_module' do
    it 'returns a puppetfile-resolver module object' do
      expect(spec.to_resolver_module).to be_a(PuppetfileResolver::Puppetfile::GitModule)
    end
  end

  context '#name' do
    let(:init_hash) { { 'git' => git, 'ref' => ref } }

    it 'resolves and returns the module name' do
      expect(spec.name).to eq(name)
    end
  end
end
