# frozen_string_literal: true

require 'spec_helper'
require 'bolt/outputter'
require 'bolt/cli'

describe "Bolt::Outputter" do
  let(:output) { StringIO.new }
  let(:outputter) { Bolt::Outputter.new(false, false, false, output) }

  let(:inventory) { Bolt::Inventory.empty }
  let(:target) { inventory.get_target('target1') }
  let(:target2) { inventory.get_target('target2') }

  let(:result) { Bolt::Result.new(target, message: "ok", action: 'action') }
  let(:err_result) { Bolt::Result.new(target2, error: { 'msg' => 'oops' }, action: 'action') }
  let(:result_set) { Bolt::ResultSet.new([result, err_result]) }
  let(:apply_result) { Bolt::ApplyResult.new(target, report: { 'status' => 'changed' }) }

  let(:error) { Bolt::Error.new("Task 'watermelon' could not be found", 'bolt/apply-prep') }

  let(:resource) { Bolt::ResourceInstance.new(resource_data) }
  let(:resource_data) do
    {
      'target'        => target,
      'type'          => 'File',
      'title'         => '/etc/puppetlabs/',
      'state'         => { 'ensure' => 'present' },
      'desired_state' => { 'ensure' => 'absent' },
      'events'        => [{ 'audited' => false }]
    }
  end

  it "formats result sets" do
    expect(outputter.stringify(result_set))
      .to eq(<<~RESULT_SET.chomp)
      [
        {
          "target": "target1",
          "action": "action",
          "object": null,
          "status": "success",
          "value": {
            "_output": "ok"
          }
        },
        {
          "target": "target2",
          "action": "action",
          "object": null,
          "status": "failure",
          "value": {
            "_error": {
              "msg": "oops"
            }
          }
        }
      ]
    RESULT_SET
  end

  it "formats a result" do
    expect(outputter.stringify(result))
      .to eq(<<~RESULT.chomp)
      {
        "target": "target1",
        "action": "action",
        "object": null,
        "status": "success",
        "value": {
          "_output": "ok"
        }
      }
    RESULT
  end

  it "formats an apply result" do
    expect(outputter.stringify(apply_result))
      .to eq(<<~APPLY_RESULT.chomp)
    {
      "target": "target1",
      "action": "apply",
      "object": null,
      "status": "success",
      "value": {
        "report": {
          "status": "changed"
        }
      }
    }
    APPLY_RESULT
  end

  it "formats resource instances" do
    expect(outputter.stringify(resource))
      .to eq("File[/etc/puppetlabs/]")
  end

  it "formats errors" do
    expect(outputter.stringify(error))
      .to eq("Task 'watermelon' could not be found")
  end

  it "formats targets" do
    expect(outputter.stringify(target))
      .to eq("target1")
  end

  it "formats arrays of complex objects" do
    expect(outputter.stringify([target, result_set, ['subarray']]))
      .to eq(<<~ARRAY.chomp)
   [
     "target1",
     [
       {
         "target": "target1",
         "action": "action",
         "object": null,
         "status": "success",
         "value": {
           "_output": "ok"
         }
       },
       {
         "target": "target2",
         "action": "action",
         "object": null,
         "status": "failure",
         "value": {
           "_error": {
             "msg": "oops"
           }
         }
       }
     ],
     [
       "subarray"
     ]
   ]
   ARRAY
  end

  it "formats hashes of complex objects" do
    expect(outputter.stringify({ target => /regex/, 'hello' => result }))
      .to eq(<<~HASH.chomp)
    {
      "target1": "(?-mix:regex)",
      "hello": {
        "target": "target1",
        "action": "action",
        "object": null,
        "status": "success",
        "value": {
          "_output": "ok"
        }
      }
    }
    HASH
  end

  it "formats unhandled objects as strings" do
    expect(outputter.stringify(/regexp/))
      .to eq('(?-mix:regexp)')
  end
end
