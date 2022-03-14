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
      init_hash['git'] = 'https://gitlab.com/puppetlabs/puppetlabs-yaml'
      expect { spec }.to raise_error(
        Bolt::ValidationError,
        /^.*is not a public GitHub repository/
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
      allow(spec).to receive(:sha).and_return(ref)
      mod = spec.to_resolver_module

      expect(mod).to be_a(PuppetfileResolver::Puppetfile::GitModule)
    end
  end

  context '#name' do
    let(:init_hash) { { 'git' => git, 'ref' => ref } }

    it 'resolves and returns the module name' do
      expect(spec.name).to eq(name)
    end

    context 'with missing metadata.json' do
      let(:git) { 'https://github.com/puppetlabs/bolt' }

      it 'errors' do
        expect { spec.name }.to raise_error(
          Bolt::Error,
          /Missing metadata\.json/
        )
      end
    end
  end

  context '#resolve_sha' do
    context 'with a valid commit' do
      let(:ref) { '79f98ffd3faf8d3badb1084a676e5fc1cbac464e' }

      it 'resolves and returns a SHA' do
        expect(spec.sha).to eq('79f98ffd3faf8d3badb1084a676e5fc1cbac464e')
      end
    end

    context 'with a valid tag' do
      let(:ref) { '0.2.0' }

      it 'resolves and returns a SHA' do
        expect(spec.sha).to eq('79f98ffd3faf8d3badb1084a676e5fc1cbac464e')
      end
    end

    context 'with a valid branch' do
      let(:ref) { 'main' }

      it 'resolves and returns a SHA' do
        expect(spec.sha).to be_a(String)
      end
    end

    context 'with an invalid ref' do
      let(:ref) { 'foobar' }

      it 'errors' do
        expect { spec.sha }.to raise_error(
          Bolt::Error,
          /not a commit, tag, or branch/
        )
      end
    end

    context 'with an invalid repository' do
      let(:git) { 'https://github.com/puppetlabs/foobarbaz' }

      it 'errors' do
        expect { spec.sha }.to raise_error(
          Bolt::Error,
          /is not a public GitHub repository/
        )
      end
    end

    it 'errors with an invalid GitHub token' do
      original = ENV['GITHUB_TOKEN']
      ENV['GITHUB_TOKEN'] = 'foo'

      expect { spec.sha }.to raise_error(
        Bolt::Error,
        /Invalid token at GITHUB_TOKEN/
      )
    ensure
      ENV['GITHUB_TOKEN'] = original
    end
  end
end
