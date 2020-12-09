# frozen_string_literal: true

require 'spec_helper'
require 'bolt/outputter'
require 'bolt/cli'
require 'bolt/plan_result'

describe "Bolt::Outputter::Rainbow" do
  let(:output) { StringIO.new }
  let(:outputter) { Bolt::Outputter::Rainbow.new(false, false, false, false, output) }
  let(:inventory) { Bolt::Inventory.empty }
  let(:target) { inventory.get_target('target1') }
  let(:target2) { inventory.get_target('target2') }
  let(:results) {
    Bolt::ResultSet.new(
      [
        Bolt::Result.new(target, message: "ok", action: 'action'),
        Bolt::Result.new(target2, error: { 'msg' => 'oops' }, action: 'action')
      ]
    )
  }

  it "colorizes output with empty results" do
    expect(outputter).to receive(:colorize).with(:rainbow, "Ran on 0 targets in 2.0 sec")
    outputter.print_head
    outputter.print_summary(Bolt::ResultSet.new([]), 2.0)
  end

  it "colorizes status output" do
    outputter.print_head
    results.each do |result|
      outputter.print_result(result)
    end
    expect(outputter).to receive(:colorize).with(:red, 'Failed on 1 target: target2').and_call_original
    # Because there's no tty this won't actually print color, so the best we
    # can test is that the right parameters are passed in
    expect(outputter).to receive(:colorize)
      .with(:rainbow, 'Successful on 1 target: target1')
      .and_call_original
    expect(outputter).to receive(:colorize)
      .with(:rainbow, 'Ran on 2 targets in 10.0 sec')
      .and_call_original
    outputter.print_summary(results, 10.0)
    lines = output.string
    summary = lines.split("\n")[-3..-1]
    expect(summary[0]).to eq('Successful on 1 target: target1')
    expect(summary[1]).to eq('Failed on 1 target: target2')
    expect(summary[2]).to eq('Ran on 2 targets in 10.0 sec')
  end

  it "colorizes guide output" do
    guide = "The trials and tribulations of Bolty McBoltface.\n"
    expect(outputter).to receive(:colorize).with(:rainbow, guide).and_call_original
    outputter.print_guide(guide, 'boltymcboltface')
    expect(output.string).to eq(guide)
  end

  it "colorizes topics list" do
    content = <<~CONTENT.chomp
      Available topics are:
      foo
      bar

      Use `bolt guide <topic>` to view a specific guide.
    CONTENT

    expect(outputter).to receive(:colorize).with(:rainbow, content)
    outputter.print_topics(%w[foo bar])
  end

  it "colorizes a message" do
    message = 'somewhere over the rainbow'
    expect(outputter).to receive(:colorize).with(:rainbow, message)
    outputter.print_message(message)
  end
end
