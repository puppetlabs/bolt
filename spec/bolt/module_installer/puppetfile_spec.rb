# frozen_string_literal: true

require 'spec_helper'

require 'bolt_spec/project'
require 'bolt/module_installer/puppetfile'

describe Bolt::ModuleInstaller::Puppetfile do
  include BoltSpec::Project

  let(:path)       { project.puppetfile }
  let(:moduledir)  { project.managed_moduledir }
  let(:name)       { 'puppetlabs/yaml' }
  let(:version)    { '0.1.0' }
  let(:mod)        { [double('mod', name: name, version: version, to_spec: "mod '#{name}'")] }
  let(:puppetfile) { described_class.new(mod) }
  let(:project)    { @project }

  around(:each) do |example|
    with_project do |project|
      @project = project
      example.run
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

    it "returns a #{described_class} with modules" do
      File.write(path, "mod 'puppetlabs-yaml', '0.2.0'")

      puppetfile = described_class.parse(path)
      expect(puppetfile).to be_a(described_class)

      expect(puppetfile.modules).to be_a(Array)
      expect(puppetfile.modules.size).to eq(1)
      expect(puppetfile.modules.first).to be_a(Bolt::ModuleInstaller::Puppetfile::ForgeModule)
    end

    it "returns a #{described_class} without modules" do
      File.write(path, '')

      puppetfile = described_class.parse(path)
      expect(puppetfile).to be_a(described_class)

      expect(puppetfile.modules).to be_a(Array)
      expect(puppetfile.modules.empty?).to be(true)
    end

    it 'errors with unsupported module types' do
      File.write(path, "mod 'yaml', local: true")
      expect { described_class.parse(path) }.to raise_error(
        Bolt::ValidationError,
        /not a Puppet Forge or Git module/
      )
    end

    it 'skips over unsupported module types' do
      File.write(path, "mod 'yaml', local: true")
      puppetfile = described_class.parse(path, skip_unsupported_modules: true)
      expect(puppetfile.modules.any?).to be(false)
    end

    it 'surfaces errors from the Puppetfile resolver' do
      File.write(path, "mod 'puppetlabs-yaml', install_path: '/foo/bar'")
      expect { described_class.parse(path) }.to raise_error(
        Bolt::ValidationError,
        /Module puppetlabs-yaml with args.*doesn't have an implementation./
      )
    end
  end

  context '#write' do
    it 'writes Forge modules to the Puppetfile' do
      puppetfile.write(path)
      expect(path.exist?).to eq(true)
      expect(File.read(path)).to match(%r{mod 'puppetlabs/yaml'})
    end

    it 'writes the moduledir to the Puppetfile' do
      puppetfile.write(path, moduledir)
      expect(path.exist?).to eq(true)
      expect(File.read(path)).to match(/moduledir '.modules'/)
    end
  end

  context '#assert_satisfies' do
    let(:specs) { double('specs', specs: [spec]) }

    context 'with satisfied specs' do
      let(:spec) { double('spec', satisfied_by?: true) }

      it 'does not error' do
        expect { puppetfile.assert_satisfies(specs) }.not_to raise_error
      end
    end

    context 'with unsatisfied specs' do
      let(:spec) { double('spec', satisfied_by?: false, to_hash: {}) }

      it 'errors' do
        expect { puppetfile.assert_satisfies(specs) }.to raise_error(
          Bolt::Error,
          /Puppetfile does not include modules that satisfy/
        )
      end
    end

    context 'with missing module version' do
      let(:spec)    { double('spec', satisfied_by?: true) }
      let(:version) { nil }

      let(:mod) do
        [double('mod', name: name, version: version, is_a?: true, to_spec: "mod '#{name}'")]
      end

      it "errors" do
        expect { puppetfile.assert_satisfies(specs) }.to raise_error(
          Bolt::Error,
          /Puppetfile includes Forge modules without a version/
        )
      end
    end
  end
end
