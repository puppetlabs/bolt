require 'spec_helper'
require 'bolt/outputter'
require 'bolt/cli'

describe "Bolt::Outputter::JSON" do
  let(:output) { StringIO.new }
  let(:outputter) { Bolt::Outputter::JSON.new(output) }
  let(:results) { { node1: Bolt::Result.new("ok") } }
  let(:config)  { Bolt::Config.new }

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
    outputter.print_result(Bolt::Node.from_uri('node1', config: config),
                           Bolt::Result.new)
    outputter.print_result(Bolt::Node.from_uri('node2', config: config),
                           Bolt::Result.new("ok"))
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
    task = {
      'name' => 'cinnamon roll',
      'description' => 'A delicious sweet bun',
      'parameters' => {
        'icing' => {
          'type' => 'Cream cheese',
          'description' => 'Rich, tangy, sweet'
        }
      }
    }
    outputter.print_task_info(task)
    expect(JSON.parse(output.string)).to eq(task)
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
    outputter.print_plan(result)

    result_hash = JSON.parse(output.string)
    expect(result_hash).to eq(result)
  end

  it "prints non-ExecutionResult from a plan" do
    result = "some data"
    outputter.print_plan(result)
    expect(output.string.strip).to eq('"' + result + '"')
  end

  it "handles fatal errors" do
    outputter.print_head
    outputter.print_result(Bolt::Node.from_uri('node1', config: config),
                           Bolt::Result.new("ok"))
    outputter.print_result(Bolt::Node.from_uri('node2', config: config),
                           Bolt::Result.new("ok"))
    outputter.fatal_error(Bolt::CLIError.new("oops"))
    parsed = JSON.parse(output.string)
    expect(parsed['items'].size).to eq(2)
    expect(parsed['_error']['kind']).to eq("bolt/cli-error")
  end
end
