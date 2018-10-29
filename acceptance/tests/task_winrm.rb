# frozen_string_literal: true

require 'bolt_command_helper'

test_name "C100551: \
           bolt task run executes puppet task on remote hosts via winrm" do
  extend Acceptance::BoltCommandHelper

  winrm_nodes = select_hosts(roles: ['winrm'])
  skip_test('no applicable nodes to test on') if winrm_nodes.empty?

  dir = bolt.tmpdir('C100551')

  step "create task on bolt controller" do
    on(bolt, "mkdir -p #{dir}/modules/test/tasks")
    create_remote_file(bolt, "#{dir}/modules/test/tasks/hostname_win.ps1", <<-FILE)
    [System.Net.Dns]::GetHostByName(($env:computerName))
    FILE
  end

  step "execute `bolt task run` via WinRM" do
    bolt_command = "bolt task run test::hostname_win"

    flags = {
      '--nodes' => 'winrm_nodes',
      '--modulepath' => "#{dir}/modules"
    }

    result = bolt_command_on(bolt, bolt_command, flags)
    winrm_nodes.each do |node|
      message = "Unexpected output from the command:\n#{result.cmd}"
      assert_match(/#{node.hostname.split('.')[0]}/, result.stdout, message)
      assert_match(/{#{node.ip}}/, result.stdout, message)
    end
  end
end
