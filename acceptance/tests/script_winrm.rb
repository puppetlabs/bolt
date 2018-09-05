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
    Write-Host "${args} from $([System.Net.Dns]::GetHostByName($env:computername).hostname)"
    FILE
  end

  step "execute `bolt script run` via WinRM" do
    bolt_command = "bolt script run #{script} hello"
    flags = { '--nodes' => 'winrm_nodes' }

    result = bolt_command_on(bolt, bolt_command, flags)
    winrm_nodes.each do |node|
      message = "Unexpected output from the command:\n#{result.cmd}"
      assert_match(/hello from #{node.hostname.split('.')[0]}/, result.stdout, message)
    end
  end
end
