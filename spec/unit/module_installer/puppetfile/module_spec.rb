# frozen_string_literal: true

require 'bolt/module_installer/puppetfile/module'

describe Bolt::ModuleInstaller::Puppetfile::Module do
  let(:name) { 'puppetlabs-yaml' }
  let(:mod)  { described_class.new(name) }

  context '#initialize' do
    it 'normalizes the full name' do
      mod = described_class.new(name)
      expect(mod.full_name).to eq('puppetlabs/yaml')
    end

    it 'extracts the module name' do
      expect(mod.name).to eq('yaml')
    end
  end
end
