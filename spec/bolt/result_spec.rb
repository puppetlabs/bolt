require 'spec_helper'
require 'json'
require 'bolt'
require 'bolt/result'

describe Bolt::Result do
  describe :from_exception do
    let(:result) do
      ex = RuntimeError.new("oops")
      ex.set_backtrace('/path/to/bolt/node.rb:42')
      Bolt::Result.from_exception(ex)
    end

    it 'has an error' do
      expect(result.error['msg']).to eq("oops")
    end

    it 'does not have a message' do
      expect(result.message).to be_nil
    end

    it 'does not have a value' do
      expect(result.value).to be_nil
    end
  end
end

describe Bolt::CommandResult do
  it 'exposes value' do
    result = Bolt::CommandResult.new("stout", "sterr", 0)
    expect(result.value).to eq('stdout' => 'stout', 'stderr' => 'sterr', 'exit_code' => 0)
  end

  it 'creates errors' do
    result = Bolt::CommandResult.new("stout", "sterr", 1)
    expect(result.error['kind']).to eq('puppetlabs.tasks/command-error')
  end
end

describe Bolt::TaskResult do
  it 'parses json objects' do
    obj = { "key" => "val" }
    result = Bolt::TaskResult.new(obj.to_json, '', 0)
    expect(result.to_result).to eq(obj)
  end

  it 'exposes value' do
    obj = { "key" => "val" }
    result = Bolt::TaskResult.new(obj.to_json, '', 0)
    expect(result.value).to eq(obj)
  end

  it 'creates the proper hash' do
    obj = { 'key' => 'val',
            '_error' => { 'msg' => 'oops' } }
    expected = { 'value' => { 'key' => 'val' },
                 'error' => { 'msg' => 'oops' } }
    result = Bolt::TaskResult.new(obj.to_json, '', 1)
    expect(result.to_h).to eq(expected)
  end

  it 'doesnt include _ keys in value' do
    obj = { "key" => "val" }
    special = { "_error" => {}, "_output" => "output" }
    result = Bolt::TaskResult.new(obj.merge(special).to_json, '', 0)
    expect(result.value).to eq(obj)
  end

  it "doesn't parse arrays" do
    stdout = '[1, 2, 3]'
    result = Bolt::TaskResult.new(stdout, '', 0)
    expect(result.to_result).to eq('_output' => stdout)
  end

  it 'handles errors' do
    obj = { "key" => "val",
            "_error" => { "kind" => "error" } }
    result = Bolt::TaskResult.new(obj.to_json, '', 1)
    expect(result.to_result).to eq(obj)
    expect(result.error).to eq(obj['_error'])
  end
end
