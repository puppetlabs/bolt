# frozen_string_literal: true

require 'bolt_command_helper'

test_name "cross-platform tasks run on multiple kinds of nodes" do
  extend Acceptance::BoltCommandHelper

  dir = bolt.tmpdir('cross_platform_task')
  task_dir = "#{dir}/modules/test/tasks"

  step "create a cross-platform task" do
    on bolt, "mkdir -p #{task_dir}"
    create_remote_file(bolt, "#{task_dir}/hostname.sh", <<-FILE)
    echo "hello from $(hostname)"
    FILE
    create_remote_file(bolt, "#{task_dir}/hostname.ps1", <<-FILE)
    [System.Net.Dns]::GetHostByName(($env:computerName))
    FILE
    create_remote_file(bolt, "#{task_dir}/hostname.json", <<-FILE)
    {
      "implementations": [
        {"name": "hostname.sh", "requirements": ["shell"]},
        {"name": "hostname.ps1", "requirements": ["powershell"]}
      ]
    }
    FILE
  end

  step "execute `bolt task run` via both SSH and WinRM" do
    bolt_command = "bolt task run test::hostname"
    flags = {
      '--nodes' => 'all',
      '--modulepath' => "#{dir}/modules"
    }

    result = bolt_command_on(bolt, bolt_command, flags)

    ssh_nodes = select_hosts(roles: ['ssh'])
    winrm_nodes = select_hosts(roles: ['winrm'])

    ssh_nodes.each do |node|
      message = "Unexpected output from the command:\n#{result.cmd}"
      regex = /hello from #{node.hostname.split('.')[0]}/
      assert_match(regex, result.stdout, message)
    end

    winrm_nodes.each do |node|
      message = "Unexpected output from the command:\n#{result.cmd}"
      assert_match(/#{node.hostname.split('.')[0]}/, result.stdout, message)
      assert_match(/{#{node.ip}}/, result.stdout, message)
    end
  end
end
