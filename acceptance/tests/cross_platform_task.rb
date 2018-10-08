# frozen_string_literal: true

require 'bolt_command_helper'

test_name "cross-platform tasks run on multiple kinds of nodes" do
  extend Acceptance::BoltCommandHelper

  dir = bolt.tmpdir('cross_platform_task')
  task_dir = "#{dir}/modules/test/tasks"
  other_module_dir = "#{dir}/modules/other/files"

  step "create a cross-platform task" do
    on bolt, "mkdir -p #{task_dir} #{other_module_dir}"
    create_remote_file(bolt, "#{task_dir}/hostname.sh", <<-FILE)
    if [ ! -f $PT__installdir/other/files/windows ]; then
      echo "hello from $(hostname)"
    fi
    cat $PT__installdir/other/files/content
    cat $PT__installdir/other/files/linux
    FILE
    create_remote_file(bolt, "#{task_dir}/hostname.ps1", <<-FILE)
    if (-Not (Test-Path $env:PT__installdir/other/files/linux)) {
      Write-Host "hello from $([System.Net.Dns]::GetHostByName(($env:computerName)).Hostname)"
    }
    cat $env:PT__installdir/other/files/content
    cat $env:PT__installdir/other/files/windows
    FILE
    create_remote_file(bolt, "#{task_dir}/hostname.json", <<-FILE)
    {
      "implementations": [
        {"name": "hostname.sh", "requirements": ["shell"], "files": ["other/files/linux"]},
        {"name": "hostname.ps1", "requirements": ["powershell"],
         "files": ["other/files/windows"], "input_method": "environment"}
      ],
      "files": ["other/files/content"]
    }
    FILE
    create_remote_file(bolt, "#{other_module_dir}/content", 'file 1')
    create_remote_file(bolt, "#{other_module_dir}/linux", 'file 2')
    create_remote_file(bolt, "#{other_module_dir}/windows", 'file 3')
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
      assert_match(/hello from #{node.hostname.split('.')[0]}/, result.stdout, message)
      assert_match(/file 1/, result.stdout, message)
      assert_match(/file 2/, result.stdout, message)
    end

    winrm_nodes.each do |node|
      message = "Unexpected output from the command:\n#{result.cmd}"
      assert_match(/hello from #{node.hostname.split('.')[0]}/, result.stdout, message)
      assert_match(/file 1/, result.stdout, message)
      assert_match(/file 3/, result.stdout, message)
    end
  end
end
