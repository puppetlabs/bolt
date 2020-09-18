# frozen_string_literal: true

require 'pathname'
require 'spec_helper'
require 'bolt/project_migrator/inventory'

describe Bolt::ProjectMigrator::Inventory do
  def migrate
    migrator.migrate(inventory_file, backup_dir)
  end

  let(:outputter)      { double('outputter', print_message: nil, print_migrate_step: nil) }
  let(:migrator)       { described_class.new(outputter) }
  let(:inventory_file) { @tmpdir + 'inventory.yaml' }
  let(:backup_dir)     { @tmpdir + '.bolt-bak' }

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

  around :each do |example|
    Dir.mktmpdir(nil, Dir.pwd) do |tmpdir|
      @tmpdir = Pathname.new(tmpdir)
      example.run
    end
  end

  it 'migrates inventory v1 to inventory v2' do
    File.write(inventory_file, inventory_v1.to_yaml)
    migrate
    expect(YAML.load_file(inventory_file)).to eq(inventory_v2)
  end

  it 'backs up the inventory before migrating' do
    File.write(inventory_file, inventory_v1.to_yaml)
    expect(migrator).to receive(:backup_file).with(inventory_file, backup_dir).and_call_original
    migrate
    expect(Dir.children(backup_dir)).to include(/#{File.basename(inventory_file)}/)
  end

  it 'does nothing when using inventory v2' do
    File.write(inventory_file, inventory_v2.to_yaml)
    expect(File).not_to receive(:write)
    migrate
    expect(YAML.load_file(inventory_file)).to eq(inventory_v2)
  end
end
