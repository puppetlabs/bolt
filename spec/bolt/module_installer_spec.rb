# frozen_string_literal: true

require 'spec_helper'
require 'bolt/module_installer'
require 'bolt/puppetfile/installer'
require 'bolt_spec/project'

describe Bolt::ModuleInstaller do
  include BoltSpec::Project

  let(:puppetfile)           { project_path + 'Puppetfile' }
  let(:moduledir)            { project_path + '.modules' }
  let(:config)               { project_path + 'bolt-project.yaml' }
  let(:new_module)           { 'puppetlabs-pkcs7' }
  let(:project_config)       { [{ 'name' => 'puppetlabs-yaml' }] }
  let(:pal)                  { double('pal', generate_types: nil) }
  let(:installer)            { described_class.new(outputter, pal) }
  let(:puppetfile_installer) { double('puppetfile_installer', install: true) }

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
    File.write(config, conf.to_yaml)
    allow(Bolt::Puppetfile::Installer).to receive(:new).and_return(puppetfile_installer)
  end

  context '#add' do
    it 'returns early if the module is already declared' do
      result = installer.add('puppetlabs-yaml', project_config, puppetfile, moduledir, config)
      expect(result).to eq(true)
      expect(puppetfile.exist?).to eq(false)
    end

    it 'errors if Puppetfile is not managed by Bolt' do
      File.write(puppetfile, '')
      expect { installer.add(new_module, project_config, puppetfile, moduledir, config) }.to raise_error(
        Bolt::Error,
        /managed by Bolt/
      )
    end

    it 'updates files and installs modules' do
      expect(puppetfile_installer).to receive(:install)
      installer.add(new_module, project_config, puppetfile, moduledir, config)

      expect(puppetfile.exist?).to be(true)
      expect(File.read(puppetfile)).to match(/mod "puppetlabs-pkcs7"/)

      conf = YAML.safe_load(File.read(config))
      expect(conf['modules']).to match_array([
                                               { 'name' => 'puppetlabs-pkcs7' }
                                             ])
    end

    it 'does not update version of installed modules' do
      spec = 'mod "puppetlabs-yaml", "0.1.0"'
      File.write(puppetfile, spec)
      result = installer.add(new_module, project_config, puppetfile, moduledir, config)

      expect(result).to eq(true)
      expect(File.read(puppetfile)).to match(/#{spec}/)
    end

    it 'updates version of installed modules if unable to resolve with pinned versions' do
      spec = 'mod "puppetlabs-ruby_task_helper", "0.3.0"'
      File.write(puppetfile, spec)
      result = installer.add(new_module, [], puppetfile, moduledir, config)

      expect(result).to eq(true)
      expect(File.read(puppetfile)).not_to match(/#{spec}/)
    end
  end

  context '#install' do
    it 'errors if Puppetfile is not managed by Bolt' do
      File.write(puppetfile, '')
      expect { installer.install(project_config, puppetfile, moduledir) }.to raise_error(
        Bolt::Error,
        /managed by Bolt/
      )
    end

    it 'installs modules forcibly' do
      File.write(puppetfile, '')
      expect(puppetfile_installer).to receive(:install)
      expect(File.read(puppetfile)).not_to match(/puppetlabs-yaml/)

      installer.install(project_config, puppetfile, moduledir, force: true)

      expect(File.read(puppetfile)).to match(/puppetlabs-yaml/)
    end

    it 'installs modules without resolving configured modules' do
      File.write(puppetfile, 'mod "puppetlabs-apache", "5.5.0"')
      expect(puppetfile_installer).to receive(:install)
      installer.install(project_config, puppetfile, moduledir, resolve: false)

      expect(File.read(puppetfile)).to match(/puppetlabs-apache/)
      expect(File.read(puppetfile)).not_to match(/puppetlabs-yaml/)
    end

    it 'writes a Puppetfile' do
      installer.install(project_config, puppetfile, moduledir)
      expect(puppetfile.exist?).to be(true)
    end

    it 'installs a Puppetfile' do
      expect(puppetfile_installer).to receive(:install)
      installer.install(project_config, puppetfile, moduledir)
    end
  end

  context '#print_puppetfile_diff' do
    let(:existing)         { double('existing', modules: existing_modules) }
    let(:updated)          { double('updated', modules: updated_modules) }
    let(:mod)              { double('existing_module', title: 'puppetlabs/foo', version: '1.0.0') }
    let(:existing_modules) { [mod] }
    let(:updated_modules)  { [] }

    it 'prints added modules' do
      updated_modules.concat([
                               mod,
                               double('updated_module', title: 'puppetlabs/bar', version: '1.0.0')
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
                               double('updated_module', title: 'puppetlabs/foo', version: '2.0.0')
                             ])

      expect(outputter).to receive(:print_action_step).with(
        %r{Upgrading the following modules:\s*puppetlabs/foo 1.0.0 to 2.0.0}
      )

      installer.print_puppetfile_diff(existing, updated)
    end

    it 'prints downgraded modules' do
      updated_modules.concat([
                               double('updated_module', title: 'puppetlabs/foo', version: '0.5.0')
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
