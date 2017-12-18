require 'spec_helper'
require 'bolt/outputter'
require 'bolt/cli'

describe "Bolt::Outputter::Human" do
  let(:output) { StringIO.new }
  let(:outputter) { Bolt::Outputter::Human.new(output) }
  let(:results) { { node1: Bolt::Result.new("ok") } }
  let(:config)  { Bolt::Config.new }

  it "starts items in head" do
    outputter.print_head
    expect(output.string).to eq('')
  end

  it "allows empty items" do
    outputter.print_head
    outputter.print_summary({}, 2.0)
    expect(output.string).to eq("Ran on 0 nodes in 2.00 seconds\n")
  end

  it "prints status" do
    outputter.print_head
    outputter.print_result(Bolt::Node.from_uri('node1', config: config),
                           Bolt::Result.new)
    outputter.print_result(Bolt::Node.from_uri('node2', config: config),
                           Bolt::Result.new('msg' => 'oops'))
    outputter.print_summary(results, 10.0)
    lines = output.string
    expect(lines).to match(/Finished on node1/)
    expect(lines).to match(/Failed on node2/)
    expect(lines).to match(/oops/)
  end

  it "formats a table" do
    outputter.print_table([%w[a b], %w[c1 d]])
    expect(output.string).to eq(<<-TABLE)
a    b
c1   d
    TABLE
  end

  it "prints CommandResults" do
    outputter.print_result(Bolt::Node.from_uri('node1', config: config),
                           Bolt::CommandResult.new("stout", "sterr", 2))
    lines = output.string
    expect(lines).to match(/STDOUT:\n    stout/)
    expect(lines).to match(/STDERR:\n    sterr/)
  end

  it "prints TaskResults" do
    result = { 'key' => 'val',
               '_error' => { 'msg' => 'oops' },
               '_output' => 'hello' }
    outputter.print_result(Bolt::Node.from_uri('node1', config: config),
                           Bolt::TaskResult.new(result.to_json, "", 2))
    lines = output.string
    expect(lines).to match(/^  oops\n  hello$/)
    expect(lines).to match(/^    "key": "val"$/)
  end

  it "prints empty results from a plan" do
    outputter.print_plan([])
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
    outputter.print_plan(result)

    result_hash = JSON.parse(output.string)
    expect(result_hash).to eq(result)
  end

  it "formats hash results from a plan" do
    result = { 'some' => 'data' }
    outputter.print_plan(result)
    expect(JSON.parse(output.string)).to eq(result)
  end

  it "prints simple output from a plan" do
    result = "some data"
    outputter.print_plan(result)
    expect(output.string.strip).to eq(result)
  end

  it "handles fatal errors" do
    outputter.fatal_error(Bolt::CLIError.new("oops"))
    expect(output.string).to eq('')
  end
end
