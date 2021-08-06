# frozen_string_literal: true

require 'spec_helper'
require 'bolt/util/format'

require 'bolt/apply_result'
require 'bolt/error'
require 'bolt/inventory'
require 'bolt/resource_instance'
require 'bolt/result'
require 'bolt/result_set'

describe Bolt::Util::Format do
  describe '#stringify' do
    let(:inventory) { Bolt::Inventory.empty }
    let(:target1)   { inventory.get_target('target1') }
    let(:target2)   { inventory.get_target('target2') }

    let(:result)       { Bolt::Result.new(target1, message: "ok", action: 'action') }
    let(:err_result)   { Bolt::Result.new(target2, error: { 'msg' => 'oops' }, action: 'action') }
    let(:result_set)   { Bolt::ResultSet.new([result, err_result]) }
    let(:apply_result) { Bolt::ApplyResult.new(target1, report: { 'status' => 'changed' }) }

    let(:error)        { Bolt::Error.new("Task 'watermelon' could not be found", 'bolt/apply-prep') }

    let(:resource) { Bolt::ResourceInstance.new(resource_data) }
    let(:resource_data) do
      {
        'target'        => target1,
        'type'          => 'File',
        'title'         => '/etc/puppetlabs/',
        'state'         => { 'ensure' => 'present' },
        'desired_state' => { 'ensure' => 'absent' },
        'events'        => [{ 'audited' => false }]
      }
    end

    it 'formats result sets' do
      expect(Bolt::Util::Format.stringify(result_set)).to eq(<<~RESULT_SET.chomp)
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

    it 'formats a result' do
      expect(Bolt::Util::Format.stringify(result)).to eq(<<~RESULT.chomp)
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

    it 'formats an apply result' do
      expect(Bolt::Util::Format.stringify(apply_result)).to eq(<<~APPLY_RESULT.chomp)
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
      expect(Bolt::Util::Format.stringify(resource)).to eq('File[/etc/puppetlabs/]')
    end

    it "formats errors" do
      expect(Bolt::Util::Format.stringify(error)).to eq("Task 'watermelon' could not be found")
    end

    it "formats targets" do
      expect(Bolt::Util::Format.stringify(target1)).to eq('target1')
    end

    it "formats arrays of complex objects" do
      expect(Bolt::Util::Format.stringify([target1, result_set, ['subarray']])).to eq(<<~ARRAY.chomp)
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
      expect(Bolt::Util::Format.stringify({ target1 => /regex/, 'hello' => result })).to eq(<<~HASH.chomp)
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
      expect(Bolt::Util::Format.stringify(/regexp/)).to eq("(?-mix:regexp)")
    end
  end
end
