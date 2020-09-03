# frozen_string_literal: true

require 'spec_helper'
require 'bolt/module_installer'
require 'bolt/puppetfile/installer'

describe Bolt::ModuleInstaller do
  let(:puppetfile)           { @project + 'Puppetfile' }
  let(:moduledir)            { @project + '.modules' }
  let(:config)               { @project + 'bolt-project.yaml' }
  let(:new_module)           { 'puppetlabs-pkcs7' }
  let(:modules_config)       { [{ 'name' => 'puppetlabs-yaml' }] }
  let(:outputter)            { double('outputter', print_message: nil, print_puppetfile_result: nil) }
  let(:pal)                  { double('pal', generate_types: nil) }
  let(:installer)            { described_class.new(outputter, pal) }
  let(:puppetfile_installer) { double('puppetfile_installer', install: true) }

  around(:each) do |example|
    Dir.mktmpdir(nil, Dir.pwd) do |project|
      @project = Pathname.new(project)
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
      result = installer.add('puppetlabs-yaml', modules_config, puppetfile, moduledir, config)
      expect(result).to eq(true)
      expect(puppetfile.exist?).to eq(false)
    end

    it 'errors if Puppetfile is not managed by Bolt' do
      File.write(puppetfile, '')
      expect { installer.add(new_module, modules_config, puppetfile, moduledir, config) }.to raise_error(
        Bolt::Error,
        /managed by Bolt/
      )
    end

    it 'updates files and installs modules' do
      expect(puppetfile_installer).to receive(:install)
      installer.add(new_module, modules_config, puppetfile, moduledir, config)

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
      result = installer.add(new_module, modules_config, puppetfile, moduledir, config)

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
      expect { installer.install(modules_config, puppetfile, moduledir) }.to raise_error(
        Bolt::Error,
        /managed by Bolt/
      )
    end

    it 'installs modules forcibly' do
      File.write(puppetfile, '')
      expect(puppetfile_installer).to receive(:install)
      installer.install(modules_config, puppetfile, moduledir, force: true)
    end

    it 'writes a Puppetfile' do
      installer.install(modules_config, puppetfile, moduledir)
      expect(puppetfile.exist?).to be(true)
    end

    it 'installs a Puppetfile' do
      expect(puppetfile_installer).to receive(:install)
      installer.install(modules_config, puppetfile, moduledir)
    end
  end
end
