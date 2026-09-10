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

  describe '#rainbow' do
    it 'returns a 6-character hex color string' do
      color = outputter.rainbow
      expect(color).to match(/\A[0-9A-F]{6}\z/)
    end

    it 'increments the color counter on each call' do
      color1 = outputter.rainbow
      color2 = outputter.rainbow
      expect(color1).not_to eq(color2)
    end
  end

  describe '#start_spin' do
    it 'spawns a spinner thread when spin=true and stream is a tty' do
      spin_output = StringIO.new
      allow(spin_output).to receive(:isatty).and_return(true)
      allow(spin_output).to receive(:print)
      spin_outputter = Bolt::Outputter::Rainbow.new(false, false, false, true, spin_output)
      spin_outputter.start_spin
      expect(spin_outputter.instance_variable_get(:@spinning)).to be true
      thread = spin_outputter.instance_variable_get(:@spin_thread)
      thread.kill if thread
    end

    it 'does not spin when stream is not a tty' do
      spin_output = StringIO.new
      allow(spin_output).to receive(:isatty).and_return(false)
      spin_outputter = Bolt::Outputter::Rainbow.new(false, false, false, true, spin_output)
      spin_outputter.start_spin
      expect(spin_outputter.instance_variable_get(:@spinning)).to be_falsey
    end
  end

  describe '#colorize' do
    context 'when stream is a TTY' do
      before(:each) { allow(output).to receive(:isatty).and_return(true) }

      it 'applies rainbow coloring to :green strings' do
        result = outputter.colorize(:green, 'hello')
        expect(result).not_to eq('hello')
      end

      it 'applies rainbow coloring to :rainbow strings' do
        result = outputter.colorize(:rainbow, 'hi')
        expect(result).not_to eq('hi')
      end

      it 'applies ANSI escape codes for non-rainbow colors' do
        result = outputter.colorize(:red, 'error')
        expect(result).to match(/\033\[31m/)
      end

      it 'handles ANSI escape sequences in the string without coloring them' do
        result = outputter.colorize(:green, "\e[0mplain")
        expect(result).to be_a(String)
      end

      it 'increments line color counter on newlines' do
        before_line = outputter.instance_variable_get(:@line_color)
        outputter.colorize(:green, "line1\nline2")
        after_line = outputter.instance_variable_get(:@line_color)
        expect(after_line).to be > before_line
      end
    end

    context 'when stream is not a TTY' do
      before(:each) { allow(output).to receive(:isatty).and_return(false) }

      it 'returns the string unchanged' do
        expect(outputter.colorize(:rainbow, 'hello')).to eq('hello')
      end
    end
  end
end
