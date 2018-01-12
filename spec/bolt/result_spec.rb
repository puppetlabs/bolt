require 'spec_helper'
require 'json'
require 'bolt'
require 'bolt/result'

describe Bolt::Result do
  let(:target) { "foo" }

  describe :from_exception do
    let(:result) do
      ex = RuntimeError.new("oops")
      ex.set_backtrace('/path/to/bolt/node.rb:42')
      Bolt::Result.from_exception(target, ex)
    end

    it 'has an error' do
      expect(result.error_hash['msg']).to eq("oops")
    end

    it 'has a target' do
      expect(result.target).to eq(target)
    end

    it 'does not have a message' do
      expect(result.message).to be_nil
    end

    it 'has an _error in value' do
      expect(result.value['_error']['msg']).to eq("oops")
    end
  end

  describe :for_command do
    it 'exposes value' do
      result = Bolt::Result.for_command(target, "stout", "sterr", 0)
      expect(result.value).to eq('stdout' => 'stout', 'stderr' => 'sterr', 'exit_code' => 0)
    end

    it 'creates errors' do
      result = Bolt::Result.for_command(target, "stout", "sterr", 1)
      expect(result.error_hash['kind']).to eq('puppetlabs.tasks/command-error')
    end
  end

  describe :for_task do
    it 'parses json objects' do
      obj = { "key" => "val" }
      result = Bolt::Result.for_task(target, obj.to_json, '', 0)
      expect(result.value).to eq(obj)
    end

    it 'doesnt include _ keys in generic_value' do
      obj = { "key" => "val" }
      special = { "_error" => {}, "_output" => "output" }
      result = Bolt::Result.for_task(target, obj.merge(special).to_json, '', 0)
      expect(result.generic_value).to eq(obj)
    end

    it "doesn't parse arrays" do
      stdout = '[1, 2, 3]'
      result = Bolt::Result.for_task(target, stdout, '', 0)
      expect(result.value).to eq('_output' => stdout)
    end

    it 'handles errors' do
      obj = { "key" => "val",
              "_error" => { "kind" => "error" } }
      result = Bolt::Result.for_task(target, obj.to_json, '', 1)
      expect(result.value).to eq(obj)
      expect(result.error_hash).to eq(obj['_error'])
    end
  end
end
