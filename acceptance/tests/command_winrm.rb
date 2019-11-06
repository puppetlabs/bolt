# frozen_string_literal: true

require 'bolt_command_helper'

test_name "C100547: \
           bolt command run should execute command on remote hosts via winrm" do
  extend Acceptance::BoltCommandHelper

  winrm_nodes = select_hosts(roles: ['winrm'])
  skip_test('no applicable nodes to test on') if winrm_nodes.empty?

  step "execute `bolt command run` via WinRM" do
    command = '[System.Net.Dns]::GetHostByName(($env:computerName))'
    bolt_command = "bolt command run '#{command}'"
    flags = { '--targets' => 'winrm_nodes' }

    result = bolt_command_on(bolt, bolt_command, flags)

    winrm_nodes.each do |node|
      message = "Unexpected output from the command:\n#{result.cmd}"
      assert_match(/#{node.hostname.split('.')[0]}/, result.stdout, message)
      assert_match(/{#{node.ip}}/, result.stdout, message)
    end
  end
end
