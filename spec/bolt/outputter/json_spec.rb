# frozen_string_literal: true

require 'spec_helper'
require 'bolt/outputter'
require 'bolt/cli'

describe "Bolt::Outputter::JSON" do
  let(:output) { StringIO.new }
  let(:outputter) { Bolt::Outputter::JSON.new(false, false, false, output) }
  let(:target1) { Bolt::Target.new('node1') }
  let(:target2) { Bolt::Target.new('node2') }
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
    task = {
      'name' => 'cinnamon roll',
      'module' => '/path/to/cinnamony/goodness',
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
    expect(JSON.parse(output.string)).to eq(task)
  end

  it "prints builtin for builtin modules" do
    task = {
      'name' => 'monkey bread',
      'files' => [{ 'name' => 'monkey_bread.rb',
                    'path' => "#{Bolt::PAL::MODULES_PATH}/monkey/bread" }],
      'metadata' => {}
    }
    outputter.print_task_info(task)
    task['module_dir'] = 'built-in module'
    expect(JSON.parse(output.string)).to eq(task)
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
end
