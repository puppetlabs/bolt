# frozen_string_literal: true

require 'spec_helper'
require 'bolt/plugin'

describe 'resolve_references' do
  include PuppetlabsSpec::Fixtures
  let(:project)       { Bolt::Project.create_project('./spec/fixtures') }
  let(:config)        { Bolt::Config.new(project, {}) }
  let(:pal)           {
    Bolt::PAL.new(Bolt::Config::Modulepath.new(config.modulepath),
                  config.hiera_config,
                  config.project.resource_types)
  }
  let(:plugins)       { Bolt::Plugin.setup(config, pal) }
  let(:executor)      { Bolt::Executor.new }
  let(:inventory)     { Bolt::Inventory.create_version({}, config.transport, config.transports, plugins) }
  let(:tasks_enabled) { true }

  let(:references) do
    {
      "targets" => {
        "_plugin" => "task",
        "task" => "test::references"
      }
    }
  end

  let(:resolved) do
    {
      "targets" => {
        "name" => "127.0.0.1"
      }
    }
  end

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
      example.run
    end
  end

  context 'calls resolve_references' do
    it 'resolves all plugin references' do
      is_expected.to run.with_params(references).and_return(resolved)
    end

    it 'errors when called with incorrect plugin data' do
      references['targets']['_plugin'] = 'fake_plugin'
      is_expected.to run.with_params(references).and_raise_error(/Unknown plugin/)
    end
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }

    it 'fails and reports that resolve_references is not available' do
      is_expected.to run
        .with_params(references)
        .and_raise_error(/Plan language function 'resolve_references' cannot be used/)
    end
  end
end
