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
                           Bolt::Result.new("ok"))
    outputter.print_result(Bolt::Node.from_uri('node2', config: config),
                           Bolt::Result.new("ok"))
    outputter.print_summary(results, 10.0)
    parsed = JSON.parse(output.string)
    expect(parsed['items'].size).to eq(2)
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
