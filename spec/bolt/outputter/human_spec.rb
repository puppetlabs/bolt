# frozen_string_literal: true

require 'spec_helper'
require 'bolt/outputter'
require 'bolt/cli'
require 'bolt/plan_result'

describe "Bolt::Outputter::Human" do
  let(:output) { StringIO.new }
  let(:outputter) { Bolt::Outputter::Human.new(false, false, false, output) }
  let(:target) { Bolt::Target.new('node1') }
  let(:target2) { Bolt::Target.new('node2') }
  let(:results) {
    Bolt::ResultSet.new(
      [
        Bolt::Result.new(target, message: "ok"),
        Bolt::Result.new(target2, error: { 'msg' => 'oops' })
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
    expect(output.string).to eq("Ran on 0 nodes in 2.00 seconds\n")
  end

  it "prints status" do
    outputter.print_head
    results.each do |result|
      outputter.print_result(result)
    end
    expect(outputter).to receive(:colorize).with(:red, 'Failed on 1 node: node2').and_call_original
    outputter.print_summary(results, 10.0)
    lines = output.string
    expect(lines).to match(/Finished on node1/)
    expect(lines).to match(/Failed on node2/)
    expect(lines).to match(/oops/)
    summary = lines.split("\n")[-3..-1]
    expect(summary[0]).to eq('Successful on 1 node: node1')
    expect(summary[1]).to eq('Failed on 1 node: node2')
    expect(summary[2]).to eq('Ran on 2 nodes in 10.00 seconds')
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
      expect(summary[0]).to eq('Successful on 2 nodes: node1,node2')
      expect(summary[1]).to eq('Ran on 2 nodes in 0.00 seconds')
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
      expect(summary[0]).to eq('Failed on 2 nodes: node1,node2')
      expect(summary[1]).to eq('Ran on 2 nodes in 0.00 seconds')
    end
  end

  it "formats a table" do
    outputter.print_table([%w[a b], %w[c1 d]])
    expect(output.string).to eq(<<-TABLE)
a    b
c1   d
    TABLE
  end

  it "formats a task" do
    task = {
      'name' => 'cinnamon_roll',
      'files' => [{ 'name' => 'cinnamon.rb',
                    'path' => '/path/to/cinnamony/goodness/tasks/cinnamon.rb' },
                  { 'name' => 'roll.sh',
                    'path' => '/path/to/wrong/module/tasks/roll.sh' }],
      'metadata' => {
        'description' => 'A delicious sweet bun',
        'parameters' => {
          'icing' => {
            'type' => 'Cream cheese',
            'description' => 'Rich, tangy, sweet'
          }
        }
      }
    }
    outputter.print_task_info(task)
    expect(output.string).to eq(<<-TASK_OUTPUT)

cinnamon_roll - A delicious sweet bun

USAGE:
bolt task run --nodes <node-name> cinnamon_roll icing=<value>

PARAMETERS:
- icing: Cream cheese
    Rich, tangy, sweet

MODULE:
/path/to/cinnamony/goodness
    TASK_OUTPUT
  end

  it 'converts Data (undef) to Any' do
    task = {
      'name' => 'sticky_bun',
      'files' => [{ 'name' => 'sticky.rb',
                    'path' => '/this/test/is/making/me/hungry/tasks/sticky.rb' },
                  { 'name' => 'bun.sh',
                    'path' => '/path/to/wrong/module/tasks/bun.sh' }],
      'metadata' => {
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
    }
    outputter.print_task_info(task)
    expect(output.string).to eq(<<-TASK_OUTPUT)

sticky_bun - A delicious sweet bun with nuts

USAGE:
bolt task run --nodes <node-name> sticky_bun glaze=<value> pecans=<value>

PARAMETERS:
- glaze: Sticky
    Sweet
- pecans: Data
    The best kind of nut

MODULE:
/this/test/is/making/me/hungry
    TASK_OUTPUT
  end

  it 'prints module path as builtin for builtin modules' do
    task = {
      'name' => 'monkey_bread',
      'files' => [{ 'name' => 'monkey_bread.rb',
                    'path' => "#{Bolt::PAL::MODULES_PATH}/monkey/bread" }],
      'metadata' => {}
    }
    outputter.print_task_info(task)
    expect(output.string).to eq(<<-TASK_OUTPUT)

monkey_bread

USAGE:
bolt task run --nodes <node-name> monkey_bread

MODULE:
built-in module
    TASK_OUTPUT
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
    expect(output.string).to eq(<<-PLAN_OUTPUT)

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
      { 'node' => 'node1', 'status' => 'finished', 'result' => { '_output' => 'yes' } },
      { 'node' => 'node2', 'status' => 'failed', 'result' =>
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
end
