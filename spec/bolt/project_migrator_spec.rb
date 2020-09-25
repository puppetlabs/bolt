# frozen_string_literal: true

require 'pathname'
require 'spec_helper'
require 'bolt/project_migrator'
require 'bolt_spec/project'

describe Bolt::ProjectMigrator do
  include BoltSpec::Project

  let(:config)    { Bolt::Config.from_project(project) }
  let(:outputter) { double('outputter', print_message: nil, print_migrate_step: nil, print_prompt: nil) }

  let(:migrator)           { described_class.new(config, outputter) }
  let(:config_migrator)    { double('config_migrator', migrate: true) }
  let(:inventory_migrator) { double('inventory_migrator', migrate: true) }
  let(:modules_migrator)   { double('modules_migrator', migrate: true) }

  around :each do |example|
    with_project do
      example.run
    end
  end

  before(:each) do
    allow($stdin).to receive(:tty?).and_return(true)
    allow(Bolt::Util).to receive(:prompt_yes_no).and_return(true)
  end

  it 'errors if stdin is not a tty' do
    allow($stdin).to receive(:tty?).and_return(false)
    expect { migrator.migrate }.to raise_error(
      Bolt::Error,
      /stdin is not a tty/
    )
  end

  it 'migrates config' do
    allow(Bolt::ProjectMigrator::Config).to receive(:new).and_return(config_migrator)
    allow(Bolt::ProjectMigrator::Inventory).to receive(:new).and_return(inventory_migrator)
    allow(Bolt::ProjectMigrator::Modules).to receive(:new).and_return(modules_migrator)
    expect(config_migrator).to receive(:migrate)
    migrator.migrate
  end

  it 'migrates inventory' do
    allow(Bolt::ProjectMigrator::Config).to receive(:new).and_return(config_migrator)
    allow(Bolt::ProjectMigrator::Inventory).to receive(:new).and_return(inventory_migrator)
    allow(Bolt::ProjectMigrator::Modules).to receive(:new).and_return(modules_migrator)
    expect(inventory_migrator).to receive(:migrate)
    migrator.migrate
  end

  it 'migrates modules' do
    allow(Bolt::ProjectMigrator::Config).to receive(:new).and_return(config_migrator)
    allow(Bolt::ProjectMigrator::Inventory).to receive(:new).and_return(inventory_migrator)
    allow(Bolt::ProjectMigrator::Modules).to receive(:new).and_return(modules_migrator)
    expect(modules_migrator).to receive(:migrate)
    migrator.migrate
  end

  it 'returns 0 if all migrations succeeded' do
    allow(Bolt::ProjectMigrator::Config).to receive(:new).and_return(config_migrator)
    allow(Bolt::ProjectMigrator::Inventory).to receive(:new).and_return(inventory_migrator)
    allow(Bolt::ProjectMigrator::Modules).to receive(:new).and_return(modules_migrator)
    expect(migrator.migrate).to eq(0)
  end

  it 'returns 1 if any migrations failed' do
    allow(Bolt::ProjectMigrator::Config).to receive(:new).and_return(double('config_migrator', migrate: false))
    allow(Bolt::ProjectMigrator::Inventory).to receive(:new).and_return(inventory_migrator)
    allow(Bolt::ProjectMigrator::Modules).to receive(:new).and_return(modules_migrator)
    expect(migrator.migrate).to eq(1)
  end
end
