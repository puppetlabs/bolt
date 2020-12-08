# frozen_string_literal: true

require 'spec_helper'
require 'bolt/module_installer'
require 'bolt_spec/project'

describe Bolt::ModuleInstaller do
  include BoltSpec::Project

  let(:puppetfile)     { project.puppetfile }
  let(:moduledir)      { project.managed_moduledir }
  let(:project_file)   { project.project_file }
  let(:new_module)     { 'puppetlabs/pkcs7' }
  let(:install_config) { {} }
  let(:specs)          { [{ 'name' => 'puppetlabs/yaml' }] }
  let(:pal)            { double('pal', generate_types: nil) }
  let(:installer)      { described_class.new(outputter, pal) }

  let(:outputter) do
    double('outputter', print_message: nil, print_puppetfile_result: nil, print_action_step: nil)
  end

  around(:each) do |example|
    with_project do
      example.run
    end
  end

  before(:each) do
    conf = { 'modules' => [] }
    File.write(project_file, conf.to_yaml)
    allow(installer).to receive(:install_puppetfile).and_return(true)
  end

  context '#add' do
    it 'returns early if the module is already declared' do
      result = installer.add('puppetlabs/yaml', specs, puppetfile, moduledir, project_file, install_config)
      expect(result).to eq(true)
      expect(puppetfile.exist?).to eq(false)
    end

    it 'errors if Puppetfile is not managed by Bolt' do
      File.write(puppetfile, '')
      expect {
        installer.add(new_module, specs, puppetfile, moduledir, project_file, install_config)
      }.to raise_error(
        Bolt::Error,
        /managed by Bolt/
      )
    end

    it 'updates files and installs modules' do
      expect(installer).to receive(:install_puppetfile)
      installer.add(new_module, specs, puppetfile, moduledir, project_file, install_config)

      expect(puppetfile.exist?).to be(true)
      expect(File.read(puppetfile)).to match(%r{mod 'puppetlabs/pkcs7'})

      conf = YAML.safe_load(File.read(project_file))
      expect(conf['modules']).to match_array(['puppetlabs/pkcs7'])
    end

    it 'does not update version of installed modules' do
      spec = "mod 'puppetlabs/yaml', '0.1.0'"
      File.write(puppetfile, spec)
      result = installer.add(new_module, specs, puppetfile, moduledir, project_file, install_config)

      expect(result).to eq(true)
      expect(File.read(puppetfile)).to match(/#{spec}/)
    end

    it 'updates version of installed modules if unable to resolve with pinned versions' do
      spec = 'mod "puppetlabs/ruby_task_helper", "0.3.0"'
      File.write(puppetfile, spec)
      result = installer.add(new_module, [], puppetfile, moduledir, project_file, install_config)

      expect(result).to eq(true)
      expect(File.read(puppetfile)).not_to match(/#{spec}/)
    end
  end

  context '#install' do
    it 'errors if Puppetfile is not managed by Bolt' do
      File.write(puppetfile, '')
      expect { installer.install(specs, puppetfile, moduledir, install_config) }.to raise_error(
        Bolt::Error,
        /managed by Bolt/
      )
    end

    it 'installs modules forcibly' do
      File.write(puppetfile, '')
      expect(installer).to receive(:install_puppetfile)
      expect(File.read(puppetfile)).not_to match(%r{puppetlabs/yaml})

      installer.install(specs, puppetfile, moduledir, install_config, force: true)

      expect(File.read(puppetfile)).to match(%r{puppetlabs/yaml})
    end

    it 'installs modules without resolving configured modules' do
      File.write(puppetfile, 'mod "puppetlabs/apache", "5.5.0"')
      expect(installer).to receive(:install_puppetfile)
      installer.install(specs, puppetfile, moduledir, install_config, resolve: false)

      expect(File.read(puppetfile)).to match(%r{puppetlabs/apache})
      expect(File.read(puppetfile)).not_to match(%r{puppetlabs/yaml})
    end

    it 'writes a Puppetfile' do
      installer.install(specs, puppetfile, moduledir, install_config)
      expect(puppetfile.exist?).to be(true)
    end

    it 'installs a Puppetfile' do
      expect(installer).to receive(:install_puppetfile)
      installer.install(specs, puppetfile, moduledir, install_config)
    end
  end

  context '#print_puppetfile_diff' do
    let(:existing)         { double('existing', modules: existing_modules) }
    let(:updated)          { double('updated', modules: updated_modules) }
    let(:existing_modules) { [mod] }
    let(:updated_modules)  { [] }

    let(:mod) do
      double('existing_module', full_name: 'puppetlabs/foo', version: '1.0.0', type: :forge)
    end

    it 'prints added modules' do
      updated_modules.concat([
                               mod,
                               double('updated_module', full_name: 'puppetlabs/bar', version: '1.0.0', type: :forge)
                             ])

      expect(outputter).to receive(:print_action_step).with(
        %r{Adding the following modules:\s*puppetlabs/bar 1.0.0}
      )

      installer.print_puppetfile_diff(existing, updated)
    end

    it 'prints removed modules' do
      expect(outputter).to receive(:print_action_step).with(
        %r{Removing the following modules:\s*puppetlabs/foo 1.0.0}
      )

      installer.print_puppetfile_diff(existing, updated)
    end

    it 'prints upgraded modules' do
      updated_modules.concat([
                               double('updated_module', full_name: 'puppetlabs/foo', version: '2.0.0', type: :forge)
                             ])

      expect(outputter).to receive(:print_action_step).with(
        %r{Upgrading the following modules:\s*puppetlabs/foo 1.0.0 to 2.0.0}
      )

      installer.print_puppetfile_diff(existing, updated)
    end

    it 'prints downgraded modules' do
      updated_modules.concat([
                               double('updated_module', full_name: 'puppetlabs/foo', version: '0.5.0', type: :forge)
                             ])

      expect(outputter).to receive(:print_action_step).with(
        %r{Downgrading the following modules:\s*puppetlabs/foo 1.0.0 to 0.5.0}
      )

      installer.print_puppetfile_diff(existing, updated)
    end

    it 'prints nothing if there is no diff' do
      expect(outputter).not_to receive(:print_action_step)

      installer.print_puppetfile_diff(existing, existing)
    end
  end
end
