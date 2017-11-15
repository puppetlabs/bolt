require 'spec_helper'
require 'json'
require 'bolt'
require 'bolt/result'

describe Bolt::TaskResult do
  it 'parses json objects' do
    obj = { "key" => "val" }
    result = Bolt::TaskResult.new(obj.to_json, '', 0)
    expect(result.to_result).to eq(obj)
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
  end
end
