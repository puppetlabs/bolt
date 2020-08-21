# frozen_string_literal: true

require 'spec_helper'
require 'bolt/outputter'
require 'bolt/project_migrate'
require 'bolt_spec/files'

describe Bolt::ProjectMigrate do
  include BoltSpec::Files

  let(:outputter) { @migrate.outputter }
  let(:backup_dir) { File.join(@migrate.path, '.bolt-bak') }
  let(:inv_data) { { 'config' => { 'ssh' => { 'user' => 'root', 'password' => 'bolt' } } } }
  let(:config_data) { { 'ssh' => { 'user' => 'bob', 'port' => 23 }, 'color' => true } }

  around :each do |example|
    Dir.mktmpdir do |project_path|
      outputter = Bolt::Outputter::Human.new(false, false, false, StringIO.new)
      @migrate = Bolt::ProjectMigrate.new(project_path, outputter)
      example.run
    end
  end

  describe "bolt_yaml_to_bolt_project" do
    it "does nothing if bolt-project.yaml exists, even if bolt.yaml exists" do
      FileUtils.touch(@migrate.project_file)
      # This is bolt.yaml, since bolt-project didn't exist when the project was created
      FileUtils.touch(@migrate.config_file)
      expect(Bolt::Util).not_to receive(:read_optional_yaml_hash)
        .with(@migrate.config_file, 'config')

      @migrate.migrate_project

      allow(outputter).to receive(:print_message) do |output|
        expect(output).to match(/bolt-project.yaml already exists/)
      end
    end

    it "does nothing if bolt.yaml does not exist" do
      expect(Bolt::Util).not_to receive(:read_optional_yaml_hash)
        .with(@migrate.config_file, 'config')

      @migrate.migrate_project

      allow(outputter).to receive(:print_message) do |output|
        expect(output).to match(/Could not find bolt.yaml in project/)
      end
    end

    it "doesn't write to inventoryfile if there's no transport config" do
      FileUtils.touch(@migrate.config_file)
      expect(File).not_to receive(:write)
        .with(@migrate.inventory_file, any_args)

      @migrate.migrate_project
    end

    context "when moving transport config" do
      before :each do
        File.write(@migrate.config_file, config_data.to_yaml)
      end

      context "with an existing inventory" do
        before :each do
          File.write(@migrate.inventory_file, inv_data.to_yaml)
        end

        it "backs up the inventory and config" do
          expect(@migrate).to receive(:backup_file)
            .with(@migrate.inventory_file).and_call_original
          expect(@migrate).to receive(:backup_file)
            .with(@migrate.config_file).and_call_original

          @migrate.migrate_project

          expect(Dir.exist?(backup_dir)).to be
          expect(Dir.children(backup_dir)).to include(/inventory.yaml.*.bak/)
          expect(Dir.children(backup_dir)).to include(/bolt.yaml.*.bak/)
        end

        it "merges config giving inventory config precedence" do
          @migrate.migrate_project
          expect(YAML.load_file(@migrate.inventory_file))
            .to eq({ 'config' => { 'ssh' => { 'user' => 'root', 'password' => 'bolt', 'port' => 23 } } })
        end

        it "removes transport config from bolt-project.yaml" do
          @migrate.migrate_project
          expect(YAML.load_file(@migrate.project_file)).to eq({ 'color' => true })
        end
      end

      context "without an existing inventory" do
        it "does not back up inventory" do
          expect(@migrate).not_to receive(:backup_file)
            .with(@migrate.inventory_file)
          expect(@migrate).to receive(:backup_file)
            .with(@migrate.config_file).and_call_original

          @migrate.migrate_project

          expect(Dir.children(backup_dir)).not_to include(/inventory.yaml.*.bak/)
        end

        it "creates a new inventory file" do
          expect(File.exist?(@migrate.inventory_file)).not_to be
          @migrate.migrate_project
          expect(File.exist?(@migrate.inventory_file)).to be
        end
      end
    end

    it "renames bolt.yaml to bolt-project.yaml" do
      File.write(@migrate.config_file, { 'color' => true }.to_yaml)
      @migrate.migrate_project
      expect(Dir.children(@migrate.path)).not_to include('bolt.yaml')
      expect(Dir.children(@migrate.path)).to include('bolt-project.yaml')
    end
  end

  describe "inventory_1_to_2" do
    let(:inventory_v1) do
      {
        "version" => 1,
        "name" => "all",
        "groups" => [
          {
            "name" => "group1",
            "nodes" => [
              {
                "name" => "target1",
                "facts" => {
                  "name" => "foo"
                }
              }
            ]
          },
          {
            "name" => "group2",
            "nodes" => [
              {
                "name" => "target2"
              }
            ]
          }
        ]
      }
    end
    let(:inventory_v2) do
      {
        "name" => "all",
        "groups" => [
          {
            "name" => "group1",
            "targets" => [
              {
                "uri" => "target1",
                "facts" => {
                  "name" => "foo"
                }
              }
            ]
          },
          {
            "name" => "group2",
            "targets" => [
              {
                "uri" => "target2"
              }
            ]
          }
        ]
      }
    end

    it 'migrates inventory v1 to inventory v2' do
      File.write(@migrate.inventory_file, inventory_v1.to_yaml)
      @migrate.migrate_project

      allow(outputter).to receive(:print_message) do |output|
        expect(output).to match(/Successfully migrated Bolt inventory/)
      end

      expect(YAML.load_file(@migrate.inventory_file)).to eq(inventory_v2)
    end

    it 'backs up the inventory before migrating' do
      expect(@migrate).to receive(:backup_file)
        .with(@migrate.inventory_file)

      File.write(@migrate.inventory_file, inventory_v1.to_yaml)
      @migrate.migrate_project
    end

    it 'does nothing when using inventory v2' do
      File.write(@migrate.inventory_file, inventory_v2.to_yaml)

      expect(File).not_to receive(:write)
      @migrate.migrate_project

      allow(outputter).to receive(:print_message) do |output|
        expect(output).to match(/Bolt inventory is already on the latest version/)
      end
      expect(YAML.load_file(@migrate.inventory_file)).to eq(inventory_v2)
    end
  end

  describe "backup_file" do
    it "copies file to project/.bolt-bak" do
      File.write(@migrate.config_file, config_data.to_yaml)
      @migrate.migrate_project
      expect(Dir.children(backup_dir).length).to eq(1)
      expect(Dir.children(backup_dir)[0]).to match(/bolt.yaml.*.bak/)
    end

    it "skips backup if the file does not exist" do
      expect(Time).not_to receive(:new)
      @migrate.migrate_project

      allow(outputter).to receive(:print_message) do |output|
        expect(output).to match(/Could not find file/)
      end
    end
  end
end
