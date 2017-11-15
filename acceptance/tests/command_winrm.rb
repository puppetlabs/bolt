require 'bolt_command_helper'
extend Acceptance::BoltCommandHelper

test_name "C100547: \
           bolt command run should execute command on remote hosts via winrm" do

  winrm_nodes = select_hosts(roles: ['winrm'])
  skip_test('no applicable nodes to test on') if winrm_nodes.empty?

  step "execute `bolt command run` via WinRM" do
    user = ENV['WINRM_USER']
    password = ENV['WINRM_PASSWORD']
    nodes_csv = winrm_nodes.map { |host| "winrm://#{host.hostname}" }.join(',')
    command = '[System.Net.Dns]::GetHostByName(($env:computerName))'
    bolt_command = "bolt command run '#{command}'"
    flags = {
      '--nodes' => nodes_csv,
      '-u'      => user,
      '-p'      => password
    }

    result = bolt_command_on(bolt, bolt_command, flags)

    winrm_nodes.each do |node|
      message = "Unexpected output from the command:\n#{result.cmd}"
      assert_match(/#{node.hostname.split('.')[0]}/, result.stdout, message)
      assert_match(/{#{node.ip}}/, result.stdout, message)
    end
  end
end
