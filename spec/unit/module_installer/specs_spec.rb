# frozen_string_literal: true

require 'spec_helper'
require 'bolt/module_installer/specs'

describe Bolt::ModuleInstaller::Specs do
  let(:specs) { described_class.new }
  let(:name)  { 'puppetlabs/yaml' }

  let(:spec1) do
    {
      'name'                => name,
      'version_requirement' => '0.1.0'
    }
  end

  let(:spec2) do
    {
      'name'                => 'puppetlabs/vault',
      'version_requirement' => '0.1.0'
    }
  end

  context '#initialize' do
    it 'errors with duplicate spec names' do
      expect { described_class.new([spec1, spec1]) }.to raise_error(
        Bolt::Error,
        /Detected multiple module specifications with name/
      )
    end
  end

  context '#add_specs' do
    it 'adds a single spec' do
      specs.add_specs(spec1)
      expect(specs.specs.size).to eq(1)
    end

    it 'adds multiple specs' do
      specs.add_specs(spec1, spec2)
      expect(specs.specs.size).to eq(2)
    end

    it 'errors with an unknown spec hash' do
      spec1.delete('name')
      expect { specs.add_specs(spec1) }.to raise_error(
        Bolt::Error,
        /Invalid module specification/
      )
    end
  end

  context '#specs' do
    it 'returns a list of unique specs' do
      specs.add_specs(spec1, spec1)
      expect(specs.specs.size).to eq(1)
    end
  end

  context '#include?' do
    let(:specs) { described_class.new(spec1) }

    it 'returns true if the specs include the given name' do
      expect(specs.include?(name)).to be(true)
    end

    it 'returns false if the specs do not include the given name' do
      expect(specs.include?('foobarbaz')).to be(false)
    end
  end

  context '#satisfied_by?' do
    let(:specs)      { described_class.new(spec) }
    let(:spec)       { double('spec', name: 'spec') }
    let(:puppetfile) { double('puppetfile', modules: [mod]) }
    let(:mod)        { double('mod') }

    it 'returns true with a Puppetfile that satisfies all specs' do
      allow(spec).to receive(:satisfied_by?).and_return(true)
      expect(specs.satisfied_by?(puppetfile)).to be(true)
    end

    it 'returns false with a Puppetfile that does not satisfy all specs' do
      allow(spec).to receive(:satisfied_by?).and_return(false)
      expect(specs.satisfied_by?(puppetfile)).to be(false)
    end
  end
end
