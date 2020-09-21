# frozen_string_literal: true

require 'spec_helper'

require 'bolt/puppetfile'

describe Bolt::Puppetfile do
  let(:path)       { @project + 'Puppetfile' }
  let(:modules)    { [{ 'name' => 'puppetlabs-yaml' }] }
  let(:puppetfile) { described_class.new(modules) }

  around(:each) do |example|
    Dir.mktmpdir(nil, Dir.pwd) do |project|
      @project = Pathname.new(project)
      example.run
    end
  end

  context '#initialize' do
    it 'turns modules into Bolt::Puppetfile::Module objects' do
      puppetfile = described_class.new(modules)

      expect(puppetfile.modules).to be_kind_of(Set)
      expect(puppetfile.modules.size).to eq(1)

      puppetfile.modules.each do |mod|
        expect(mod).to be_kind_of(Bolt::Puppetfile::Module)
      end
    end
  end

  context '#parse' do
    it 'errors if unable to parse the Puppetfile' do
      File.write(path, "mod 'puppetlabs-yaml' '0.2.0'")

      expect { described_class.parse(path) }.to raise_error(
        Bolt::Error,
        /Unable to parse Puppetfile/
      )
    end

    it 'returns a list of Bolt::Puppetfile::Module objects' do
      File.write(path, "mod 'puppetlabs-yaml', '0.2.0'")

      puppetfile = described_class.parse(path)

      expect(puppetfile.modules).to be_kind_of(Set)
      expect(puppetfile.modules.size).to eq(1)

      puppetfile.modules.each do |mod|
        expect(mod).to be_kind_of(Bolt::Puppetfile::Module)
      end
    end

    it 'handles git modules' do
      File.write(path, "mod 'puppetlabs-yaml', git: 'https://github.com/puppetlabs/puppetlabs-yaml', branch: 'master'")
      expect { described_class.parse(path) }.not_to raise_error
    end
  end

  context '#write' do
    it 'writes modules to the Puppetfile' do
      puppetfile.write(path)
      expect(path.exist?).to eq(true)
      expect(File.read(path)).to match(/mod "puppetlabs-yaml"/)
    end
  end

  context '#resolve' do
    context 'with unknown modules' do
      let(:modules) { [{ 'name' => 'puppetlabs-boltymcboltface' }] }

      it 'errors' do
        expect { puppetfile.resolve }.to raise_error(
          Bolt::Error,
          /Unknown module name/
        )
      end
    end

    it 'resolves dependencies and returns a list of Bolt::Puppetfile::Module objects' do
      modules = puppetfile.resolve

      expect(modules).to be_kind_of(Set)
      expect(modules.size).to be > 1

      modules.each do |mod|
        expect(mod).to be_kind_of(Bolt::Puppetfile::Module)
      end
    end

    context 'with a specific version' do
      let(:modules) { [{ 'name' => 'puppetlabs-facts', 'version_requirement' => '0.5.0' }] }

      it 'resolves' do
        modules = puppetfile.resolve.to_a
        expect(modules.first.version).to eq('0.5.0')
      end
    end

    context 'with version shorthand' do
      let(:modules) { [{ 'name' => 'puppetlabs-facts', 'version_requirement' => '0.x' }] }

      it 'resolves' do
        modules = puppetfile.resolve.to_a
        expect(modules.first.version).to eq('0.6.0')
      end
    end

    context 'with a version range' do
      let(:modules) { [{ 'name' => 'puppetlabs-facts', 'version_requirement' => '>= 0.2.0 < 0.4.0' }] }

      it 'resolves' do
        modules = puppetfile.resolve.to_a
        expect(modules.first.version).to eq('0.3.1')
      end
    end
  end
end
