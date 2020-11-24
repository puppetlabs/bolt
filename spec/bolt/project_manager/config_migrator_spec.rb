# frozen_string_literal: true

require 'pathname'
require 'spec_helper'
require 'bolt_spec/project'
require 'bolt/project_manager/config_migrator'

describe Bolt::ProjectManager::ConfigMigrator do
  include BoltSpec::Project

  def migrate
    migrator.migrate(config_file, project_file, inventory_file, backup_dir)
  end

  let(:outputter)      { double('outputter', print_message: nil, print_action_step: nil) }
  let(:migrator)       { described_class.new(outputter) }
  let(:inventory_file) { project_dir + 'inventory.yaml' }
  let(:config_file)    { project_dir + 'bolt.yaml' }
  let(:project_file)   { project_dir + 'bolt-project.yaml' }
  let(:backup_dir)     { project_dir + '.bolt-bak' }

  context "updating options" do
    let(:project_dir) { project.path }

    let(:old_config) do
      {
        'apply_settings' => {
          'show_diff' => true
        },
        'plugin_hooks' => {
          'puppet_library' => {
            'collection' => 'puppet6'
          }
        }
      }
    end

    let(:new_config) do
      {
        'apply-settings' => {
          'show_diff' => true
        },
        'plugin-hooks' => {
          'puppet_library' => {
            'collection' => 'puppet6'
          }
        }
      }
    end

    around :each do |example|
      with_project do
        example.run
      end
    end

    context "with deprecated options" do
      let(:project_config) { old_config }

      it "updates configuration options" do
        migrate
        expect(YAML.load_file(project_file)).to eq(new_config)
      end
    end

    context "with deprecated and non-deprecated options" do
      let(:project_config) { old_config.merge(new_config) }

      it "removes deprecated options" do
        migrate
        expect(YAML.load_file(project_file)).to eq(new_config)
      end
    end
  end

  context "when moving transport config" do
    let(:project_dir) { @tmpdir }

    let(:inv_data) do
      {
        'config' => {
          'ssh' => {
            'user' => 'root',
            'password' => 'bolt'
          }
        }
      }
    end

    let(:config_data) do
      {
        'color' => true,
        'ssh' => {
          'user' => 'bob',
          'port' => 23
        }
      }
    end

    around :each do |example|
      Dir.mktmpdir(nil, Dir.pwd) do |tmpdir|
        @tmpdir = Pathname.new(tmpdir)
        example.run
      end
    end

    it "does nothing if bolt-project.yaml exists, even if bolt.yaml exists" do
      FileUtils.touch(project_file)
      FileUtils.touch(config_file)
      expect(Bolt::Util).not_to receive(:read_optional_yaml_hash).with(config_file, 'config')
      migrate
    end

    it "does nothing if bolt.yaml does not exist" do
      expect(Bolt::Util).not_to receive(:read_optional_yaml_hash).with(config_file, 'config')
      migrate
    end

    it "doesn't write to inventoryfile if there's no transport config" do
      FileUtils.touch(config_file)
      expect(File).not_to receive(:write).with(inventory_file, any_args)
      migrate
    end

    context "with an existing inventory" do
      before :each do
        File.write(config_file, config_data.to_yaml)
        File.write(inventory_file, inv_data.to_yaml)
      end

      it "backs up the inventory and config" do
        expect(migrator).to receive(:backup_file).with(inventory_file, backup_dir).and_call_original
        expect(migrator).to receive(:backup_file).with(config_file, backup_dir).and_call_original

        migrate

        expect(Dir.exist?(backup_dir)).to be
        expect(Dir.children(backup_dir)).to include(/inventory.yaml.*.bak/, /bolt.yaml.*.bak/)
      end

      it "merges config giving inventory config precedence" do
        migrate
        expect(YAML.load_file(inventory_file))
          .to eq({ 'config' => { 'ssh' => { 'user' => 'root', 'password' => 'bolt', 'port' => 23 } } })
      end

      it "removes transport config from bolt-project.yaml" do
        migrate
        expect(YAML.load_file(project_file)).to eq({ 'color' => true })
      end
    end

    context "without an existing inventory" do
      before :each do
        File.write(config_file, config_data.to_yaml)
      end

      it "does not back up inventory" do
        expect(migrator).not_to receive(:backup_file)
          .with(inventory_file, backup_dir)
        expect(migrator).to receive(:backup_file)
          .with(config_file, backup_dir).and_call_original

        migrate

        expect(Dir.children(backup_dir)).not_to include(/inventory.yaml.*.bak/)
      end

      it "creates a new inventory file" do
        expect(File.exist?(inventory_file)).not_to be
        migrate
        expect(File.exist?(inventory_file)).to be
      end
    end
  end
end
