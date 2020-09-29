# frozen_string_literal: true

require 'spec_helper'

require 'bolt/puppetfile/module'

describe Bolt::Puppetfile::Module do
  context '#initialize' do
    it 'creates a new module' do
      expect(described_class.new('owner', 'name', '1.1.0')).to be
    end

    it 'does not require a version' do
      expect(described_class.new('owner', 'name')).to be
    end

    it 'does not set version if version is :latest' do
      mod = described_class.new('owner', 'name', :latest)
      expect(mod.version).to be(nil)
    end
  end

  context '#from_hash' do
    it 'returns a module' do
      expect(described_class.from_hash('name' => 'puppetlabs-apt')).to be_kind_of(described_class)
    end

    it 'errors if the name does not include the owner and module name' do
      expect { described_class.from_hash('name' => 'apt') }.to raise_error(
        Bolt::ValidationError,
        /Module name apt must include both the owner and module name/
      )
    end
  end

  context '#title' do
    it 'returns the module title' do
      expect(described_class.new('owner', 'name').title).to eq('owner-name')
    end
  end

  context '#eql?' do
    it 'returns true for modules with the same owner and name' do
      mod1 = described_class.new('owner', 'title')
      mod2 = described_class.new('owner', 'title')

      expect(mod1.eql?(mod2)).to eq(true)
    end

    it 'returns false for modules with differing titles' do
      mod1 = described_class.new('owner', 'title')
      mod2 = described_class.new('author', 'title')

      expect(mod1.eql?(mod2)).to eq(false)
    end

    it 'returns true if versions intersect' do
      mod1 = described_class.new('owner', 'title', '1.0.0')
      mod2 = described_class.new('owner', 'title', '>= 1.0.0')

      expect(mod1.eql?(mod2)).to eq(true)
    end

    it 'returns false if versions do not intersect' do
      mod1 = described_class.new('owner', 'title', '1.0.0')
      mod2 = described_class.new('owner', 'title', '>= 2.0.0')

      expect(mod1.eql?(mod2)).to eq(false)
    end
  end

  context '#hash' do
    it 'errors without a name key' do
      expect { described_class.from_hash('title' => 'puppetlabs-apt') }.to raise_error(
        Bolt::ValidationError,
        /Module name must be a String/
      )
    end

    it 'errors if name is not a String' do
      expect { described_class.from_hash('name' => 42) }.to raise_error(
        Bolt::ValidationError,
        /Module name must be a String/
      )
    end

    it 'hashes from owner and name' do
      mod1 = described_class.new('puppetlabs', 'apt')
      mod2 = described_class.new('puppetlabs', 'apt')
      mod3 = described_class.new('puppetlabs', 'yaml')
      expect(Set.new([mod1, mod2, mod3]).size).to eq(2)
    end

    it 'hashes from version intersection' do
      mod1 = described_class.new('puppetlabs', 'apt', '1.0.0')
      mod2 = described_class.new('puppetlabs', 'apt', '1.x')
      mod3 = described_class.new('puppetlabs', 'apt', '>= 2.0.0')
      expect(Set.new([mod1, mod2, mod3]).size).to eq(2)
    end
  end

  context '#to_spec' do
    it 'returns a Puppetfile module spec' do
      expect(described_class.new('owner', 'name', '1.0.0').to_spec).to eq(
        'mod "owner-name", "1.0.0"'
      )
    end

    it 'returns a Puppetfile module spec with no verison' do
      expect(described_class.new('owner', 'name').to_spec).to eq(
        'mod "owner-name"'
      )
    end
  end
end
