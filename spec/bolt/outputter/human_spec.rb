# frozen_string_literal: true

require 'spec_helper'
require 'bolt/outputter'
require 'bolt/cli'
require 'bolt/plan_result'

describe "Bolt::Outputter::Human" do
  let(:output) { StringIO.new }
  let(:outputter) { Bolt::Outputter::Human.new(false, false, false, false, output) }
  let(:inventory) { Bolt::Inventory.empty }
  let(:target) { inventory.get_target('target1') }
  let(:target2) { inventory.get_target('target2') }
  let(:results) {
    Bolt::ResultSet.new(
      [
        Bolt::Result.new(target, message: "ok", action: 'action'),
        Bolt::Result.new(target2, error: { 'msg' => 'oops' }, action: 'action')
      ]
    )
  }

  it "starts items in head" do
    outputter.print_head
    expect(output.string).to eq('')
  end

  it "allows empty items" do
    outputter.print_head
    outputter.print_summary(Bolt::ResultSet.new([]), 2.0)
    expect(output.string).to eq("Ran on 0 targets in 2.0 sec\n")
  end

  it "prints status" do
    outputter.print_head
    results.each do |result|
      outputter.print_result(result)
    end
    expect(outputter).to receive(:colorize).with(:red, 'Failed on 1 target: target2').and_call_original
    outputter.print_summary(results, 10.0)
    lines = output.string
    expect(lines).to match(/Finished on target1/)
    expect(lines).to match(/Failed on target2/)
    expect(lines).to match(/oops/)
    summary = lines.split("\n")[-3..-1]
    expect(summary[0]).to eq('Successful on 1 target: target1')
    expect(summary[1]).to eq('Failed on 1 target: target2')
    expect(summary[2]).to eq('Ran on 2 targets in 10.0 sec')
  end

  context 'with multiple successes' do
    let(:results) {
      Bolt::ResultSet.new(
        [
          Bolt::Result.new(target, message: 'ok'),
          Bolt::Result.new(target2, message: 'also ok')
        ]
      )
    }

    it 'prints success, omits failure' do
      outputter.print_summary(results, 0.0)
      summary = output.string.split("\n")
      expect(summary[0]).to eq('Successful on 2 targets: target1,target2')
      expect(summary[1]).to eq('Ran on 2 targets in 0.0 sec')
    end
  end

  context 'with multiple failures' do
    let(:results) {
      Bolt::ResultSet.new(
        [
          Bolt::Result.new(target, error: { 'msg' => 'oops' }),
          Bolt::Result.new(target2, error: { 'msg' => 'also oops' })
        ]
      )
    }

    it 'prints success, omits failure' do
      outputter.print_summary(results, 0.0)
      summary = output.string.split("\n")
      expect(summary[0]).to eq('Failed on 2 targets: target1,target2')
      expect(summary[1]).to eq('Ran on 2 targets in 0.0 sec')
    end
  end

  it "formats a table" do
    output = outputter.format_table([%w[a b], %w[c1 d]])
    expect(output.to_s).to eq(<<~TABLE.chomp)
      a    b
      c1   d
    TABLE
  end

  it 'formats a modules with padding' do
    modules = { "/modulepath" =>
                [{ name: "boltlib", version: nil, internal_module_group: "Plan Language Modules" },
                 { name: "ctrl", version: nil, internal_module_group: "Plan Language Modules" },
                 { name: "dir", version: nil, internal_module_group: "Plan Language Modules" }] }
    outputter.print_module_list(modules)
    expect(output.string).to eq(<<~TABLE)
    Plan Language Modules
      boltlib   (built-in)
      ctrl      (built-in)
      dir       (built-in)

    TABLE
  end

  it "formats a task" do
    name = 'cinnamon_roll'
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

    command = if Bolt::Util.powershell?
                'Invoke-BoltTask -Name cinnamon_roll -Targets <targets> icing=<value>'
              else
                'bolt task run cinnamon_roll --targets <targets> icing=<value>'
              end

    outputter.print_task_info(task: Bolt::Task.new(name, metadata, files))
    expect(output.string).to match(/cinnamon_roll.*A delicious sweet bun/m),
                             'Does not print name and description'
    expect(output.string).to match(/Usage.*#{Regexp.escape(command)}/m),
                             'Does not print usage string'
    expect(output.string).to match(/Parameters.*icing.*Cream cheese/m),
                             'Does not print parameters'
    expect(output.string).to match(%r{Module.*/path/to/cinnamony/goodness}m),
                             'Does not print module path'
  end

  it 'succeeds if task parameters do not have a type' do
    name = 'donut'
    files = [{ 'name' => 'glazed.rb',
               'path' => '/path/to/glazed.rb' }]
    metadata = {
      'parameters' => {
        'flavor' => {
          'description' => 'What flavor of donut'
        }
      }
    }

    outputter.print_task_info(task: Bolt::Task.new(name, metadata, files))
    expect(output.string).to match(/flavor.*Any/)
  end

  it 'prints noop option in the usage if task supports noop' do
    name = 'test'
    files = [{
      'name' => 'test.rb',
      'path' => '/path/to/test.rb'
    }]
    metadata = {
      'description' => 'A test task',
      'supports_noop' => true
    }

    option = (Bolt::Util.powershell? ? '[-Noop]' : '[--noop]')

    outputter.print_task_info(task: Bolt::Task.new(name, metadata, files))
    expect(output.string).to match(Regexp.escape(option))
  end

  it 'prints modulepath as builtin for builtin modules' do
    name = 'monkey_bread'
    files = [{ 'name' => 'monkey_bread.rb',
               'path' => "#{Bolt::Config::Modulepath::MODULES_PATH}/monkey/bread" }]
    metadata = {}

    outputter.print_task_info(task: Bolt::Task.new(name, metadata, files))
    expect(output.string).to match(/Module.*built-in module/m)
  end

  it 'prints correct file separator for modulepath' do
    task = {
      'name' => 'monkey_bread',
      'files' => [{ 'name' => 'monkey_bread.rb',
                    'path' => "#{Bolt::Config::Modulepath::MODULES_PATH}/monkey/bread" }],
      'metadata' => {}
    }
    outputter.print_tasks(tasks: [task], modulepath: %w[path1 path2])
    expect(output.string).to include("path1#{File::PATH_SEPARATOR}path2")
  end

  it "formats a plan" do
    plan = {
      'name' => 'planity_plan',
      'module' => 'plans/plans/plans/plans',
      'parameters' => {
        'foo' => {
          'type' => 'Bar'
        },
        'baz' => {
          'type' => 'Bar',
          'default_value' => nil
        }
      }
    }

    command = if Bolt::Util.powershell?
                'Invoke-BoltPlan -Name planity_plan [baz=<value>] foo=<value>'
              else
                'bolt plan run planity_plan [baz=<value>] foo=<value>'
              end

    outputter.print_plan_info(plan)

    expect(output.string).to match(/planity_plan.*No description/m),
                             'Does not print plan name and description'
    expect(output.string).to match(/Usage.*#{Regexp.escape(command)}/m),
                             'Does not print usage string'
    expect(output.string).to match(/Parameters.*baz.*Bar.*foo.*Bar/m),
                             'Does not print parameters'
    expect(output.string).to match(%r{Module.*plans/plans/plans/plans}m),
                             'Does not print module path'
  end

  it "prints CommandResults" do
    value = {
      'stdout'        => 'stdout',
      'stderr'        => 'stderr',
      'merged_output' => "stdout\nstderr",
      'exit_code'     => 2
    }

    outputter.print_result(Bolt::Result.for_command(target, value, 'command', "executed", []))
    expect(output.string).to match(/stdout.*stderr/m)
  end

  it "prints TaskResults" do
    result = { 'key' => 'val',
               '_error' => { 'msg' => 'oops' },
               '_output' => 'hello' }
    outputter.print_result(Bolt::Result.for_task(target, result.to_json, "", 2, 'atask', []))
    lines = output.string
    expect(lines).to match(/^  oops\n  hello$/)
    expect(lines).to match(/^    "key": "val"$/)
  end

  it 'prints lookup results' do
    result = Bolt::Result.for_lookup(target, 'key', 'value')
    outputter.print_result(result)
    expect(output.string).to match(/Finished on #{target}.*value/m)
  end

  it "doesn't stacktrace when merged_output is nil" do
    value = {
      'stdout'        => 'stdout',
      'stderr'        => 'stderr',
      'merged_output' => nil,
      'exit_code'     => 2
    }
    expect {
      outputter.print_result(Bolt::Result.for_command(target, value, 'command', "executed", []))
    }.not_to raise_error
    expect(output.string).to match(/stdout.*stderr/m)
  end

  it "prints empty results from a plan" do
    outputter.print_plan_result(Bolt::PlanResult.new([], 'success'))
    expect(output.string).to eq("[\n\n]\n")
  end

  it "formats unwrapped ExecutionResult from a plan" do
    result = [
      { 'target' => 'target1', 'status' => 'finished', 'result' => { '_output' => 'yes' } },
      { 'target' => 'target2', 'status' => 'failed', 'result' =>
        { '_error' => { 'message' => 'The command failed with exit code 2',
                        'kind' => 'puppetlabs.tasks/command-error',
                        'issue_code' => 'COMMAND_ERROR',
                        'partial_result' => { 'stdout' => 'no', 'stderr' => '', 'exit_code' => 2 },
                        'details' => { 'exit_code' => 2 } } } }
    ]
    outputter.print_plan_result(Bolt::PlanResult.new(result, 'failure'))

    result_hash = JSON.parse(output.string)
    expect(result_hash).to eq(result)
  end

  it "formats hash results from a plan" do
    result = { 'some' => 'data' }
    outputter.print_plan_result(Bolt::PlanResult.new(result, 'success'))
    expect(JSON.parse(output.string)).to eq(result)
  end

  it "prints simple output from a plan" do
    result = "some data"
    outputter.print_plan_result(Bolt::PlanResult.new(result, 'success'))
    expect(output.string.strip).to eq("\"#{result}\"")
  end

  it "prints a message when a plan returns undef" do
    outputter.print_plan_result(Bolt::PlanResult.new(nil, 'success'))
    expect(output.string.strip).to eq("Plan completed successfully with no result")
  end

  it "prints the result of installing a Puppetfile successfully" do
    outputter.print_puppetfile_result(true, '/path/to/Puppetfile', '/path/to/modules')
    expect(output.string.strip).to eq("Successfully synced modules from /path/to/Puppetfile to /path/to/modules")
  end

  it "prints the result of installing a Puppetfile with a failure" do
    outputter.print_puppetfile_result(false, '/path/to/Puppetfile', '/path/to/modules')
    expect(output.string.strip).to eq("Failed to sync modules from /path/to/Puppetfile to /path/to/modules")
  end

  it "handles fatal errors" do
    outputter.fatal_error(Bolt::CLIError.new("oops"))
    expect(output.string).to eq("oops\n")
  end

  it "handles message events" do
    outputter.handle_event(type: :message, message: "hello world")
    expect(output.string).to eq("hello world\n")
  end

  it "handles nested default_output commands" do
    outputter.instance_variable_set(:@plan_depth, 1)
    outputter.handle_event(type: :disable_default_output)
    outputter.handle_event(type: :disable_default_output)
    outputter.handle_event(type: :enable_default_output)
    outputter.handle_event(type: :step_start, description: "step", targets: [target])
    expect(output.string).to eq("")
  end

  it "prints messages when default_output is disabled" do
    outputter.instance_variable_set(:@plan_depth, 1)
    outputter.handle_event(type: :disable_default_output)
    outputter.handle_event(type: :message, message: "hello!")
    expect(output.string).to eq("hello!\n")
  end

  context '#duration_to_string' do
    it 'includes only seconds when the duration is less than a minute' do
      str = outputter.duration_to_string(34)
      expect(str).to eq("34 sec")
    end

    it 'includes up to two decimal places if the duration is less than a minute' do
      str = outputter.duration_to_string(34.5678)
      expect(str).to eq("34.57 sec")
    end

    it 'includes minutes when the duration is more than a minute' do
      str = outputter.duration_to_string(99)
      expect(str).to eq("1 min, 39 sec")
    end

    it 'rounds to the nearest whole second if the duration is more than a minute' do
      str = outputter.duration_to_string(99.99)
      expect(str).to eq("1 min, 40 sec")
    end

    it 'includes hours when the duration is more than an hour' do
      str = outputter.duration_to_string(3750)
      expect(str).to eq("1 hr, 2 min, 30 sec")
    end
  end

  it 'prints a list of guide topics' do
    outputter.print_topics(topics: %w[apple banana carrot])
    expect(output.string).to eq(<<~OUTPUT)
      Topics
        apple
        banana
        carrot

      Additional information
        Use 'bolt guide <TOPIC>' to view a specific guide.
    OUTPUT
  end

  it 'prints a guide' do
    guide = "The trials and tribulations of Bolty McBoltface\n"
    outputter.print_guide(guide: guide, topic: 'boltymcboltface')
    expect(output.string).to eq(guide)
  end

  it 'prints a plan-hierarchy lookup result' do
    value = 'peanut butter'
    outputter.print_plan_lookup(value)
    expect(output.string.strip).to eq(value)
  end

  it 'does not spin when spinner is set to false' do
    outputter.start_spin
    sleep(0.3)
    expect(output.string).not_to include("\b\\\b|")
    outputter.stop_spin
  end

  context 'with spinner enabled' do
    let(:outputter) { Bolt::Outputter::Human.new(false, false, false, true, output) }

    it 'spins while executing with a block' do
      expect(output).to receive(:isatty).twice.and_return(true)
      outputter.spin do
        sleep(0.3)
        expect(output.string).to include("\\\b|\b")
      end
    end

    it 'spins between start and stop' do
      expect(output).to receive(:isatty).twice.and_return(true)
      outputter.start_spin
      sleep(0.3)
      expect(output.string).to include("\\\b|\b")
      outputter.stop_spin
    end

    it 'does not spin when stdout is not a TTY' do
      expect(output).to receive(:isatty).twice.and_return(false)
      outputter.start_spin
      sleep(0.3)
      expect(output.string).not_to include("\b\\\b|")
      outputter.stop_spin
    end
  end

  context 'targets' do
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

    context '#print_targets' do
      it 'prints adhoc targets' do
        outputter.print_targets(**data)
        expect(output.string).to match(/target\s*\(Not found in inventory file\)/)
      end

      it 'prints the inventory source' do
        outputter.print_targets(**data)
        expect(output.string).to match(/Inventory source.*#{inventoryfile}/m)
      end

      it 'prints a message that the inventory file does not exist' do
        data[:inventory][:file] = nil
        outputter.print_targets(**data)
        expect(output.string).to match(/Inventory source.*does not exist/m)
      end

      it 'prints target counts' do
        outputter.print_targets(**data)
        expect(output.string).to match(/2 total, 1 from inventory, 1 adhoc/)
      end

      it 'prints suggestion to use a targeting option if one was not provided' do
        data[:flag] = false
        outputter.print_targets(**data)
        expect(output.string).to match(/Use the .* option to view specific targets/)
      end

      it 'does not print suggestion to use a targeting option if one was provided' do
        outputter.print_targets(**data)
        expect(output.string).not_to match(/Use the .* option to view specific targets/)
      end

      it 'prints suggestion to use detail option' do
        outputter.print_targets(**data)
        expect(output.string).to match(/Use the .* option to view target configuration and data/)
      end
    end

    context '#print_target_info' do
      it 'prints suggestion to use a targeting option if one was not provided' do
        data[:flag] = false
        outputter.print_target_info(**data)
        expect(output.string).to match(/Use the .* option to view specific targets/)
      end

      it 'does not print suggestion to use a targeting option if one was provided' do
        outputter.print_target_info(**data)
        expect(output.string).not_to match(/Use the .* option to view specific targets/)
      end

      it 'does not print suggestion to use detail option' do
        outputter.print_target_info(**data)
        expect(output.string).not_to match(/Use the .* option to view target configuration and data/)
      end
    end
  end

  context '#print_groups' do
    let(:inventoryfile) { '/path/to/inventory' }
    let(:groups)        { %w[apple banana carrot] }

    let(:data) do
      {
        groups:    groups,
        inventory: {
          source:  inventoryfile,
          default: inventoryfile
        },
        count:     groups.count
      }
    end

    it 'prints groups' do
      outputter.print_groups(**data)
      expect(output.string).to match(/Groups.*apple.*banana.*carrot/m)
    end

    it 'prints the inventory source' do
      outputter.print_groups(**data)
      expect(output.string).to match(/Inventory source.*#{inventoryfile}/m)
    end

    it 'prints that the inventory file does not exist' do
      data[:inventory][:source] = nil
      outputter.print_groups(**data)
      expect(output.string).to match(/Inventory source.*but the file does not exist/m)
    end

    it 'prints the group count' do
      outputter.print_groups(**data)
      expect(output.string).to match(/Group count.*3 total/m)
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

      expect(output.string).to match(/puppet_library.*resolve_reference/m),
                               'Does not print hook names'
      expect(output.string).to match(/task.*custom_plugin.*quiet_plugin/m),
                               'Does not print plugin names'
      expect(output.string).to match(/My custom plugin/),
                               'Does not print descriptions'
      expect(output.string).to match(/Install the Puppet agent package.*\.\.\./),
                               'Does not truncate descriptions'
      expect(output.string).to match(/Modulepath.*#{modulepath.join(File::PATH_SEPARATOR)}/m),
                               'Does not print modulepath'
    end
  end
end
