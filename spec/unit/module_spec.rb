# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/files'
require 'bolt/module'

describe Bolt::Module do
  include BoltSpec::Files

  let(:modulepath) { [fixtures_path('modules')] }
  let(:project)    { double('project', load_as_module?: false) }
  let(:mods)       { Bolt::Module.discover(modulepath, project) }

  it 'returns the path' do
    expect(mods['vars'].name).to eq('vars')
    expect(mods['vars'].path).to eq(fixtures_path(%w[modules vars]))
    expect(mods['vars'].plugin?).to eq(false)
  end

  describe '.discover' do
    it 'includes project module when load_as_module? is true' do
      Dir.mktmpdir do |mod_path|
        proj = double('project', load_as_module?: true, name: 'myproject', path: Pathname.new(mod_path))
        result = Bolt::Module.discover([], proj)
        expect(result).to have_key('myproject')
        expect(result['myproject'].name).to eq('myproject')
      end
    end

    it 'skips non-existent modulepath entries' do
      proj = double('project', load_as_module?: false)
      result = Bolt::Module.discover(['/nonexistent/path'], proj)
      expect(result).to be_empty
    end

    it 'skips modules with invalid names' do
      Dir.mktmpdir do |path|
        FileUtils.mkdir(File.join(path, 'InvalidName'))
        FileUtils.mkdir(File.join(path, 'valid_name'))
        proj = double('project', load_as_module?: false)
        result = Bolt::Module.discover([path], proj)
        expect(result).not_to have_key('InvalidName')
        expect(result).to have_key('valid_name')
      end
    end

    it 'first module path wins for shadowed modules' do
      Dir.mktmpdir do |path1|
        Dir.mktmpdir do |path2|
          FileUtils.mkdir(File.join(path1, 'mymod'))
          FileUtils.mkdir(File.join(path2, 'mymod'))
          proj = double('project', load_as_module?: false)
          result = Bolt::Module.discover([path1, path2], proj)
          expect(result['mymod'].path).to eq(File.join(path1, 'mymod'))
        end
      end
    end
  end

  describe '#plugin_data_file' do
    it 'returns the path to bolt_plugin.json' do
      mod = Bolt::Module.new('mymod', '/path/to/mymod')
      expect(mod.plugin_data_file).to eq('/path/to/mymod/bolt_plugin.json')
    end
  end

  describe '#plugin?' do
    it 'returns true when bolt_plugin.json exists' do
      Dir.mktmpdir do |path|
        File.write(File.join(path, 'bolt_plugin.json'), '{}')
        mod = Bolt::Module.new('mymod', path)
        expect(mod.plugin?).to be true
      end
    end

    it 'returns false when neither plugin file exists' do
      Dir.mktmpdir do |path|
        mod = Bolt::Module.new('mymod', path)
        expect(mod.plugin?).to be false
      end
    end

    it 'logs a warning when the deprecated bolt-plugin.json exists' do
      Dir.mktmpdir do |path|
        File.write(File.join(path, 'bolt-plugin.json'), '{}')
        mod = Bolt::Module.new('mymod', path)
        expect(Bolt::Logger).to receive(:warn_once)
        mod.plugin?
      end
    end
  end
end
