# frozen_string_literal: true

require 'spec_helper'
require 'bolt/executor'
require 'bolt/inventory'

describe 'out::message' do
  let(:executor)  { Bolt::Executor.new }
  let(:outputter) { stub('outputter', handle_event: nil) }

  let(:inventory) { Bolt::Inventory.empty }
  let(:target)    { inventory.get_target('target1') }
  let(:target2)   { inventory.get_target('target2') }

  let(:result)       { Bolt::Result.new(target, message: "ok", action: 'action') }
  let(:err_result)   { Bolt::Result.new(target2, error: { 'msg' => 'oops' }, action: 'action') }
  let(:result_set)   { Bolt::ResultSet.new([result, err_result]) }
  let(:apply_result) { Bolt::ApplyResult.new(target, report: { 'status' => 'changed' }) }

  let(:error)        { Bolt::Error.new("Task 'watermelon' could not be found", 'bolt/apply-prep') }
  let(:puppet_error) { Puppet::DataTypes::Error.new('Something went terribly, terribly wrong!') }

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

  around(:each) do |example|
    executor.subscribe(outputter)

    Puppet[:tasks] = true
    Puppet.override(bolt_executor: executor) do
      example.run
    end
  end

  it "sends a message event to the executor" do
    executor.expects(:publish_event).with(type: :message, message: 'hello world')
    is_expected.to run.with_params('hello world')
  end

  it "formats result sets" do
    executor.expects(:publish_event).with(type: :message, message: <<~RESULT_SET.chomp)
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

    is_expected.to run.with_params(result_set)
  end

  it "formats a result" do
    executor.expects(:publish_event).with(type: :message, message: <<~RESULT.chomp)
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

    is_expected.to run.with_params(result)
  end

  it "formats an apply result" do
    executor.expects(:publish_event).with(type: :message, message: <<~APPLY_RESULT.chomp)
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

    is_expected.to run.with_params(apply_result)
  end

  it "formats resource instances" do
    executor.expects(:publish_event).with(type: :message, message: "File[/etc/puppetlabs/]")
    is_expected.to run.with_params(resource)
  end

  it "formats errors" do
    executor.expects(:publish_event).with(type: :message, message: "Task 'watermelon' could not be found")
    is_expected.to run.with_params(error)
  end

  it "formats targets" do
    executor.expects(:publish_event).with(type: :message, message: "target1")
    is_expected.to run.with_params(target)
  end

  it "formats arrays of complex objects" do
    executor.expects(:publish_event).with(type: :message, message: <<~ARRAY.chomp)
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

    is_expected.to run.with_params([target, result_set, ['subarray']])
  end

  it "formats hashes of complex objects" do
    executor.expects(:publish_event).with(type: :message, message: <<~HASH.chomp)
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

    is_expected.to run.with_params({ target => /regex/, 'hello' => result })
  end

  it "formats preformatted Puppet errors" do
    executor.expects(:publish_event).with(
      type: :message,
      message: "Error({'msg' => 'Something went terribly, terribly wrong!'})"
    )

    is_expected.to run.with_params(puppet_error)
  end

  it "formats unhandled objects as strings" do
    executor.expects(:publish_event).with(type: :message, message: "(?-mix:regexp)")
    is_expected.to run.with_params(/regexp/)
  end
end
