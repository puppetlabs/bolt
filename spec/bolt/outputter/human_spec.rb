# frozen_string_literal: true

require 'spec_helper'
require 'bolt/outputter'
require 'bolt/cli'
require 'bolt/plan_result'

describe "Bolt::Outputter::Human" do
  let(:output) { StringIO.new }
  let(:outputter) { Bolt::Outputter::Human.new(false, false, false, output) }
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
    outputter.print_table([%w[a b], %w[c1 d]])
    expect(output.string).to eq(<<~TABLE)
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
    outputter.print_task_info(Bolt::Task.new(name, metadata, files))
    expect(output.string).to eq(<<~TASK_OUTPUT)

      cinnamon_roll - A delicious sweet bun

      USAGE:
      bolt task run --targets <node-name> cinnamon_roll icing=<value>

      PARAMETERS:
      - icing: Cream cheese
          Rich, tangy, sweet

      MODULE:
      /path/to/cinnamony/goodness
    TASK_OUTPUT
  end

  it 'converts Data (undef) to Any' do
    name = 'sticky_bun'
    files = [{ 'name' => 'sticky.rb',
               'path' => '/this/test/is/making/me/hungry/tasks/sticky.rb' },
             { 'name' => 'bun.sh',
               'path' => '/path/to/wrong/module/tasks/bun.sh' }]
    metadata = {
      'description' => 'A delicious sweet bun with nuts',
      'parameters' => {
        'glaze' => {
          'type' => 'Sticky',
          'description' => 'Sweet'
        },
        'pecans' => {
          'description' => 'The best kind of nut',
          'type' => 'Data'
        }
      }
    }
    outputter.print_task_info(Bolt::Task.new(name, metadata, files))
    expect(output.string).to eq(<<~TASK_OUTPUT)

      sticky_bun - A delicious sweet bun with nuts

      USAGE:
      bolt task run --targets <node-name> sticky_bun glaze=<value> pecans=<value>

      PARAMETERS:
      - glaze: Sticky
          Sweet
      - pecans: Data
          The best kind of nut

      MODULE:
      /this/test/is/making/me/hungry
    TASK_OUTPUT
  end

  it 'prints modulepath as builtin for builtin modules' do
    name = 'monkey_bread'
    files = [{ 'name' => 'monkey_bread.rb',
               'path' => "#{Bolt::Config::Modulepath::MODULES_PATH}/monkey/bread" }]
    metadata = {}
    outputter.print_task_info(Bolt::Task.new(name, metadata, files))
    expect(output.string).to eq(<<~TASK_OUTPUT)

      monkey_bread

      USAGE:
      bolt task run --targets <node-name> monkey_bread

      MODULE:
      built-in module
    TASK_OUTPUT
  end

  it 'prints correct file separator for modulepath' do
    task = {
      'name' => 'monkey_bread',
      'files' => [{ 'name' => 'monkey_bread.rb',
                    'path' => "#{Bolt::Config::Modulepath::MODULES_PATH}/monkey/bread" }],
      'metadata' => {}
    }
    outputter.print_tasks([task], %w[path1 path2])
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
    outputter.print_plan_info(plan)
    expect(output.string).to eq(<<~PLAN_OUTPUT)

      planity_plan

      USAGE:
      bolt plan run planity_plan foo=<value> [baz=<value>]

      PARAMETERS:
      - foo: Bar
      - baz: Bar

      MODULE:
      plans/plans/plans/plans
    PLAN_OUTPUT
  end

  it "prints CommandResults" do
    outputter.print_result(Bolt::Result.for_command(target, "stout", "sterr", 2, 'command', "executed"))
    lines = output.string
    expect(lines).to match(/STDOUT:\n    stout/)
    expect(lines).to match(/STDERR:\n    sterr/)
  end

  it "prints TaskResults" do
    result = { 'key' => 'val',
               '_error' => { 'msg' => 'oops' },
               '_output' => 'hello' }
    outputter.print_result(Bolt::Result.for_task(target, result.to_json, "", 2, 'atask'))
    lines = output.string
    expect(lines).to match(/^  oops\n  hello$/)
    expect(lines).to match(/^    "key": "val"$/)
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
    outputter.print_topics(%w[apple banana carrot])
    expect(output.string).to eq(<<~OUTPUT)
      Available topics are:
      apple
      banana
      carrot

      Use `bolt guide <topic>` to view a specific guide.
    OUTPUT
  end

  it 'prints a guide' do
    guide = "The trials and tribulations of Bolty McBoltface\n"
    outputter.print_guide(guide, 'boltymcboltface')
    expect(output.string).to eq(guide)
  end

  context '#print_targets' do
    let(:inventoryfile) { '/path/to/inventory' }

    let(:target_list) do
      {
        inventory: [double('target', name: 'target')],
        adhoc:     [double('target', name: 'target')]
      }
    end

    it 'prints adhoc targets' do
      outputter.print_targets(target_list, inventoryfile)
      expect(output.string).to match(/target\s*\(Not found in inventory file\)/)
    end

    it 'prints the inventory file path' do
      expect(File).to receive(:exist?).with(inventoryfile).and_return(true)
      outputter.print_targets(target_list, inventoryfile)
      expect(output.string).to match(/INVENTORY FILE:\s*#{inventoryfile}/)
    end

    it 'prints a message that the inventory file does not exist' do
      expect(File).to receive(:exist?).with(inventoryfile).and_return(false)
      outputter.print_targets(target_list, inventoryfile)
      expect(output.string).to match(/INVENTORY FILE:.*does not exist/m)
    end

    it 'prints target counts' do
      outputter.print_targets(target_list, inventoryfile)
      expect(output.string).to match(/2 total, 1 from inventory, 1 adhoc/)
    end
  end
end
