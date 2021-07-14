# frozen_string_literal: true

require 'spec_helper'
require 'bolt/outputter'
require 'bolt/cli'

describe "Bolt::Outputter::JSON" do
  let(:output) { StringIO.new }
  let(:outputter) { Bolt::Outputter::JSON.new(false, false, false, false, output) }
  let(:inventory) { Bolt::Inventory.empty }
  let(:target1) { inventory.get_target('target1') }
  let(:target2) { inventory.get_target('target2') }
  let(:results) { { node1: Bolt::Result.new(target1, value: { 'msg' => "ok" }) } }

  it "starts items in head" do
    outputter.print_head
    expect(output.string).to match(/"items": \[\w*\Z/)
  end

  it "allows empty items" do
    outputter.print_head
    outputter.print_summary(results, 10.0)
    parsed = JSON.parse(output.string)
    expect(parsed['items']).to eq([])
  end

  it "prints multiple items" do
    outputter.print_head
    outputter.print_result(Bolt::Result.new(target1))
    outputter.print_result(Bolt::Result.new(target2, error: { 'msg' => 'oops' }))
    outputter.print_summary(results, 10.0)
    parsed = JSON.parse(output.string)
    expect(parsed['items'].size).to eq(2)
    expect(parsed['items'][0]['status']).to eq('success')
    expect(parsed['items'][1]['status']).to eq('failure')
  end

  it "formats a table" do
    table = [%w[a b], %w[c1 d]]
    outputter.print_table(table)
    expect(JSON.parse(output.string)).to eq(table)
  end

  it "formats a task" do
    name = 'cinnamon roll'
    files = [{ 'name' => 'cinnamon.rb',
               'path' => '/path/to/cinnamony/goodness/tasks/cinnamon.rb' },
             { 'name' => 'roll.sh',
               'path' => '/path/to/wrong/module/tasks/roll.sh' }]
    metadata = {
      'description' => 'A delicious sweet bun',
      'parameters' => {
        'icing' => {
          'type' => 'Cream cheese',
          'description' => 'Rich, tangy, sweet'
        }
      }
    }

    result = {
      'name' => name,
      'files' => files,
      'metadata' => metadata,
      'module_dir' => '/path/to/cinnamony/goodness'
    }
    outputter.print_task_info(task: Bolt::Task.new(name, metadata, files))
    expect(JSON.parse(output.string)).to eq(result)
  end

  it "prints builtin for builtin modules" do
    name = 'monkey bread'
    files = [{ 'name' => 'monkey_bread.rb',
               'path' => "#{Bolt::Config::Modulepath::MODULES_PATH}/monkey/bread" }]
    metadata = {}

    result = {
      'name' => name,
      'files' => files,
      'metadata' => metadata,
      'module_dir' => 'built-in module'
    }

    outputter.print_task_info(task: Bolt::Task.new(name, metadata, files))
    expect(JSON.parse(output.string)).to eq(result)
  end

  it "formats a plan" do
    plan = {
      'name' => 'planity_plan',
      'module' => 'plan/plan/plan',
      'files' => [{ 'name' => 'planity',
                    'path' => 'plan/plan' }],
      'parameters' => [
        {
          'name' => 'foo',
          'type' => 'Bar'
        },
        {
          'name' => 'baz',
          'type' => 'Bar',
          'default_value' => nil
        }
      ]
    }
    outputter.print_plan_info(plan)
    expect(JSON.parse(output.string)).to eq(plan)
  end

  it "formats ExecutionResult from a plan" do
    result = [
      { 'node' => 'node1', 'status' => 'finished', 'result' => { '_output' => 'yes' } },
      { 'node' => 'node2', 'status' => 'failed', 'result' =>
        { '_error' => { 'message' => 'The command failed with exit code 2',
                        'kind' => 'puppetlabs.tasks/command-error',
                        'issue_code' => 'COMMAND_ERROR',
                        'partial_result' => { 'stdout' => 'no', 'stderr' => '', 'exit_code' => 2 },
                        'details' => { 'exit_code' => 2 } } } }
    ]
    outputter.print_plan_result(result)

    result_hash = JSON.parse(output.string)
    expect(result_hash).to eq(result)
  end

  it "prints non-ExecutionResult from a plan" do
    result = "some data"
    outputter.print_plan_result(result)
    expect(output.string.strip).to eq('"' + result + '"')
  end

  it "prints the result of installing a Puppetfile" do
    outputter.print_puppetfile_result(true, '/path/to/Puppetfile', '/path/to/modules')
    parsed = JSON.parse(output.string)
    expect(parsed['success']).to eq(true)
    expect(parsed['puppetfile']).to eq('/path/to/Puppetfile')
    expect(parsed['moduledir']).to eq('/path/to/modules')
  end

  it "handles fatal errors" do
    outputter.print_head
    outputter.print_result(Bolt::Result.new(target1, value: { 'msg' => "ok" }))
    outputter.print_result(Bolt::Result.new(target2, value: { 'msg' => "ok" }))
    outputter.fatal_error(Bolt::CLIError.new("oops"))
    parsed = JSON.parse(output.string)
    expect(parsed['items'].size).to eq(2)
    expect(parsed['_error']['kind']).to eq("bolt/cli-error")
  end

  it 'prints a list of guides' do
    topics = %w[apple banana carrot]

    outputter.print_topics(topics: topics)
    parsed = JSON.parse(output.string)

    expect(parsed['topics']).to match_array(topics)
  end

  it 'prints a guide page' do
    topic = 'boltymcboltface'
    guide = "The trials and tribulations of Bolty McBoltface.\n"

    outputter.print_guide(guide: guide, topic: 'boltymcboltface')
    parsed = JSON.parse(output.string)

    expect(parsed['topic']).to eq(topic)
    expect(parsed['guide']).to eq(guide)
  end

  it 'prints a plan-hierarchy lookup value' do
    value = 'peanut butter'
    outputter.print_plan_lookup(value)
    expect { JSON.parse(output.string) }.not_to raise_error
    expect(output.string.strip).to eq("\"#{value}\"")
  end

  context '#print_targets' do
    let(:inventoryfile) { '/path/to/inventory' }
    let(:target)        { { 'name' => 'target' } }

    let(:data) do
      {
        adhoc: {
          count: 1,
          targets: [target]
        },
        inventory: {
          count: 1,
          targets: [target],
          file: inventoryfile,
          default: inventoryfile
        },
        targets: [target, target],
        count: 2,
        flag: true
      }
    end

    it 'outputs inventory targets with count and file' do
      outputter.print_targets(**data)
      parsed = JSON.parse(output.string)

      expect(parsed['inventory']).to eq(
        'targets' => ['target'],
        'count'   => 1,
        'file'    => inventoryfile,
        'default' => inventoryfile
      )
    end

    it 'outputs adhoc targets with count' do
      outputter.print_targets(**data)
      parsed = JSON.parse(output.string)

      expect(parsed['adhoc']).to eq(
        'targets' => ['target'],
        'count'   => 1
      )
    end

    it 'outputs all targets with count' do
      outputter.print_targets(**data)
      parsed = JSON.parse(output.string)

      expect(parsed['targets']).to match_array(%w[target target])
      expect(parsed['count']).to eq(2)
    end
  end

  context '#print_groups' do
    let(:inventoryfile) { '/path/to/inventory' }
    let(:groups)        { %w[apple banana carrot] }

    it 'outputs groups, count, and inventoryfile' do
      outputter.print_groups(count: groups.count, groups: groups, inventory: inventoryfile)

      expect(JSON.parse(output.string)).to eq(
        'groups' => groups,
        'count' => groups.count
      )
    end
  end

  context '#print_plugin_list' do
    let(:modulepath) { ['path/to/module', 'other/path/to/module'] }

    let(:plugins) do
      {
        puppet_library: {
          'task' => 'Install the Puppet agent package by running a custom task as a plugin'
        },
        resolve_reference: {
          'custom_plugin' => 'My custom plugin',
          'quiet_plugin'  => nil
        }
      }
    end

    it 'prints a list of plugins' do
      outputter.print_plugin_list(plugins: plugins, modulepath: modulepath)

      expect(JSON.parse(output.string)).to eq(
        'plugins'    => plugins.transform_keys(&:to_s),
        'modulepath' => modulepath
      )
    end
  end
end
