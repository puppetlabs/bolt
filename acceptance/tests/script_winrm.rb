# frozen_string_literal: true

require 'bolt_command_helper'

test_name "C100549: \
           bolt script run should execute script on remote hosts via winrm" do
  extend Acceptance::BoltCommandHelper

  winrm_nodes = select_hosts(roles: ['winrm'])
  skip_test('no applicable nodes to test on') if winrm_nodes.empty?

  script = "C100549.ps1"

  step "create powershell script on bolt controller" do
    create_remote_file(bolt, script, <<-FILE)
    [System.Net.Dns]::GetHostByName(($env:computerName))
    FILE
  end

  step "execute `bolt script run` via WinRM" do
    bolt_command = "bolt script run #{script}"
    flags = { '--nodes' => 'winrm_nodes' }

    result = bolt_command_on(bolt, bolt_command, flags)
    winrm_nodes.each do |node|
      message = "Unexpected output from the command:\n#{result.cmd}"
      assert_match(/#{node.hostname.split('.')[0]}/, result.stdout, message)
      assert_match(/{#{node.ip}}/, result.stdout, message)
    end
  end

  rb_script = "C100549.rb"
  step "create ruby script on bolt controller" do
    create_remote_file(bolt, rb_script, <<-FILE)
    1001.times { |t| puts t }
    FILE
  end

  step "execute `bolt script run` via WinRM for Ruby script and verify output is in-order" do
    bolt_command = "bolt script run #{rb_script}"
    flags = { '--nodes' => 'winrm_nodes', '--format' => 'json' }

    result = bolt_command_on(bolt, bolt_command, flags)

    begin
      json = JSON.parse(result.stdout)
    rescue JSON.ParserError
      assert_equal("Output should be JSON", result.string,
                   "Output should be JSON")
    end

    winrm_nodes.each do |node|
      output = json['items'].select { |n| n['node'] == node.hostname }.first
      expected = (0..1000).to_a.join("\r\n")
      assert_equal(output['result']['stdout'].chomp, expected)
    end
  end
end
