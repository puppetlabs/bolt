require 'spec_helper'
require 'bolt/outputter'
require 'bolt/cli'

describe "Bolt::Outputter::Human" do
  let(:output) { StringIO.new }
  let(:outputter) { Bolt::Outputter::Human.new(output) }
  let(:config) { Bolt::Config.new }
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
      'description' => 'A delicious sweet bun',
      'parameters' => {
        'icing' => {
          'type' => 'Cream cheese',
          'description' => 'Rich, tangy, sweet'
        }
      }
    }
    outputter.print_task_info(task)
    expect(output.string).to eq(<<-TASK_OUTPUT)

cinnamon_roll - A delicious sweet bun

USAGE:
bolt task run --nodes, -n <node-name> cinnamon_roll icing=<value>

PARAMETERS:
- icing: Cream cheese
    Rich, tangy, sweet

    TASK_OUTPUT
  end

  it 'converts Data (undef) to Any' do
    task = {
      'name' => 'sticky_bun',
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
    outputter.print_task_info(task)
    expect(output.string).to eq(<<-TASK_OUTPUT)

sticky_bun - A delicious sweet bun with nuts

USAGE:
bolt task run --nodes, -n <node-name> sticky_bun glaze=<value> pecans=<value>

PARAMETERS:
- glaze: Sticky
    Sweet
- pecans: Any
    The best kind of nut

    TASK_OUTPUT
  end

  it "formats a plan" do
    plan = {
      'name' => 'planity_plan',
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
    expect(output.string).to eq(<<-PLAN_OUTPUT)

planity_plan

USAGE:
bolt plan run planity_plan foo=<value> [baz=<value>]

PARAMETERS:
- foo: Bar
- baz: Bar

    PLAN_OUTPUT
  end

  it "prints CommandResults" do
    outputter.print_result(Bolt::Result.for_command(target, "stout", "sterr", 2))
    lines = output.string
    expect(lines).to match(/STDOUT:\n    stout/)
    expect(lines).to match(/STDERR:\n    sterr/)
  end

  it "prints TaskResults" do
    result = { 'key' => 'val',
               '_error' => { 'msg' => 'oops' },
               '_output' => 'hello' }
    outputter.print_result(Bolt::Result.for_task(target, result.to_json, "", 2))
    lines = output.string
    expect(lines).to match(/^  oops\n  hello$/)
    expect(lines).to match(/^    "key": "val"$/)
  end

  it "prints empty results from a plan" do
    outputter.print_plan_result([])
    expect(output.string).to eq("[]\n")
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
    outputter.print_plan_result(result)

    result_hash = JSON.parse(output.string)
    expect(result_hash).to eq(result)
  end

  it "formats hash results from a plan" do
    result = { 'some' => 'data' }
    outputter.print_plan_result(result)
    expect(JSON.parse(output.string)).to eq(result)
  end

  it "prints simple output from a plan" do
    result = "some data"
    outputter.print_plan_result(result)
    expect(output.string.strip).to eq("\"#{result}\"")
  end

  it "handles fatal errors" do
    outputter.fatal_error(Bolt::CLIError.new("oops"))
    expect(output.string).to eq("oops\n")
  end
end
