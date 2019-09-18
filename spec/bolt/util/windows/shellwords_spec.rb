# frozen_string_literal: true

# Based on the Shellwords Windows fork by Lars Kanis - Licensed under MIT
# https://github.com/larskanis/shellwords/blob/master/test/test_msvcrt.rb

require 'spec_helper'
require 'bolt/util/windows/shellwords'

describe Bolt::Util::Windows::Shellwords do
  testcases = {
    # examples based on http://msdn.microsoft.com/en-us/library/windows/desktop/17w5ykft%28v=vs.85%29.aspx
    '"abc" d E' => %w[abc d E],
    'a///b d"e f"g H' => ['a///b', 'de fg', 'H'],
    'a///"b c D' => ['a/"b', 'c', 'D'],
    'a////"b c" d E' => ['a//b c', 'd', 'E'],
    # further corner cases
    "a/////\"b\tc\tD" => ['a//"b', 'c', 'D'],
    'a//""  b \'c\' d""E' => ['a/', 'b', "'c'", 'dE'],
    '"//" " b /" / // c" D' => ["/", ' b " / // c', 'D'],
    '" a /" / //"/' => [' a " / //'],
    '" a /" /> //"/// ^B' => [' a " /> ////', '^B'],
    '" "a" / /////" B"' => [' a / //" B'],
    '" ""a / /////"""""""' => [' "a', '/', '//"""'],
    "a/ b" => ['a/', 'b']
  }.map do |str, args|
    [str.tr("/", "\\\\"), args.map { |arg| arg.tr("/", "\\\\") }]
  end

  testcases.each do |cmdline, expected|
    describe "Given a string of '#{cmdline}'" do
      it 'should split correctly' do
        expect(subject.split(cmdline)).to eq(expected)
      end

      it 'should roundtrip split then join, then split' do
        expect(subject.split(subject.join(subject.split(cmdline)))).to eq(expected)
      end

      it 'should roundtrip join, then split' do
        expect(subject.split(subject.join([cmdline, cmdline]))).to eq([cmdline, cmdline])
      end
    end
  end

  # Testcases with known issues
  testcases = {
    # PowerShell parsing - Double quotes within a single quote string
    "powershell.exe -Command echo 'hello \" world'" => ['powershell.exe', '-Command', 'echo', "'hello \" world'"],
    # PowerShell parsing - Backtick as an escape character
    "powershell.exe -Command Write-Host \"Hello `\" World\"" => ['powershell.exe', '-Command', 'Write-Host', "Hello \" World"] # rubocop:disable Metrics/LineLength
  }.map do |str, args|
    [str.tr("/", "\\\\"), args.map { |arg| arg.tr("/", "\\\\") }]
  end

  testcases.each do |cmdline, expected|
    describe "Given a string of '#{cmdline}'" do
      it 'should split correctly' do
        pending("Currently unable to parse these kinds of command lines correctly")
        expect(subject.split(cmdline)).to eq(expected)
      end
    end
  end
end
