# frozen_string_literal: true

require 'spec_helper'
require 'bolt/module_installer/installer'

describe Bolt::ModuleInstaller::Installer do
  let(:path)      { (@project + 'Puppetfile').expand_path }
  let(:moduledir) { (@project + 'modules').expand_path }
  let(:installer) { described_class.new }

  around(:each) do |example|
    Dir.mktmpdir(nil, Dir.pwd) do |project|
      @project = Pathname.new(project)
      example.run
    end
  end

  context '#install' do
    it 'errors if the Puppetfile does not exist' do
      expect { installer.install(path, moduledir) }.to raise_error(
        Bolt::Error,
        /Could not find a Puppetfile/
      )
    end

    it 'installs the modules to the modulepath' do
      File.write(path, "mod 'puppetlabs-yaml', '0.2.0'")

      result = installer.install(path, moduledir)

      expect(result).to be
      expect(Dir.exist?(moduledir)).to eq(true)
      expect(Dir.children(moduledir)).to match_array(['yaml'])
    end
  end
end
