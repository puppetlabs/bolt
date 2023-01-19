# frozen_string_literal: true

require 'spec_helper'
require 'puppetfile-resolver'
require 'bolt/module_installer/resolver'

describe Bolt::ModuleInstaller::Resolver do
  let(:name)      { 'yaml' }
  let(:full_name) { "puppetlabs/#{name}" }
  let(:version)   { '0.1.0' }
  let(:git)       { "https://github.com/puppetlabs/puppetlabs-#{name}" }
  let(:ref)       { '0.1.0' }
  let(:mod)       { forge_module }
  let(:resolve)   { true }
  let(:resolver)  { described_class.new }
  let(:specs)     { double('specs', specs: [spec]) }
  let(:type)      { :forge }

  let(:spec) do
    double(
      'spec',
      to_resolver_module: mod,
      full_name: name,
      name: name,
      git: git,
      sha: ref,
      ref: ref,
      resolve: resolve,
      type: type,
      version_requirement: version
    )
  end

  let(:forge_module) do
    PuppetfileResolver::Puppetfile::ForgeModule.new(full_name).tap do |mod|
      mod.version = version
    end
  end

  let(:git_module) do
    PuppetfileResolver::Puppetfile::GitModule.new(full_name).tap do |mod|
      mod.remote = git
      mod.ref    = ref
    end
  end

  context 'with forge modules' do
    it 'resolves and returns a Puppetfile object' do
      result = resolver.resolve(specs)

      expect(result).to be_a(Bolt::ModuleInstaller::Puppetfile)
      expect(result.modules.count).to eq(2)
      expect(result.modules.map(&:name)).to match_array(%w[ruby_task_helper yaml])
    end

    context 'with resolve set to false' do
      let(:resolve) { false }

      it 'does not resolve and returns a Puppetfile object' do
        result = resolver.resolve(specs)

        expect(result).to be_a(Bolt::ModuleInstaller::Puppetfile)
        expect(result.modules.count).to eq(1)
        expect(result.modules.map(&:name)).to match_array(%w[yaml])
      end
    end
  end

  context 'with git modules' do
    let(:mod) { git_module }

    it 'resolves and returns a Puppetfile object' do
      result = resolver.resolve(specs)

      expect(result).to be_a(Bolt::ModuleInstaller::Puppetfile)
      expect(result.modules.count).to eq(2)
      expect(result.modules.map(&:name)).to match_array(%w[ruby_task_helper yaml])
    end

    context 'with resolve set to false' do
      let(:resolve) { false }
      let(:type)    { :git }

      it 'does not resolve and returns a Puppetfile object' do
        result = resolver.resolve(specs)

        expect(result).to be_a(Bolt::ModuleInstaller::Puppetfile)
        expect(result.modules.count).to eq(1)
        expect(result.modules.map(&:name)).to match_array(%w[yaml])
      end
    end
  end

  context 'with unknown modules' do
    let(:name) { 'foobarbaz' }

    it 'errors' do
      expect { resolver.resolve(specs) }.to raise_error(
        Bolt::Error,
        /could not find compatible versions for possibility named "foobarbaz"/
      )
    end
  end

  context 'with incompatable module dependencies' do
    let(:name)      { 'kubeinstall' }
    let(:full_name) { "aursu/#{name}" }
    let(:version)   { '0.2.1' }

    it 'errors' do
      expect { resolver.resolve(specs) }.to raise_error(Bolt::Error)
    end
  end

  context 'with unknown module versions' do
    let(:version) { '0.0.1' }

    it 'errors' do
      expect { resolver.resolve(specs) }.to raise_error(
        Bolt::Error,
        /could not find compatible versions for possibility named "#{name}"/
      )
    end
  end
end
