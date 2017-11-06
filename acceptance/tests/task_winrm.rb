require 'bolt_command_helper'
extend Acceptance::BoltCommandHelper

test_name "C100551: \
           bolt task run executes puppet task on remote hosts via winrm" do

  winrm_nodes = select_hosts(roles: ['winrm'])
  skip_test('no applicable nodes to test on') if winrm_nodes.empty?

  dir = bolt.tmpdir('C100551')

  step "create task on bolt controller" do
    on(bolt, "mkdir -p #{dir}/modules/test/tasks")
    create_remote_file(bolt, "#{dir}/modules/test/tasks/hostname_win", <<-FILE)
    [System.Net.Dns]::GetHostByName(($env:computerName))
    FILE
  end

  step "execute `bolt task run` via WinRM" do
    user = ENV['WINRM_USER']
    password = ENV['WINRM_PASSWORD']
    nodes_csv = winrm_nodes.map { |host| "winrm://#{host.hostname}" }.join(',')
    bolt_command = "bolt task run test::hostname_win"

    flags = {
      '--nodes'       => nodes_csv,
      '--modulepath'  => "#{dir}/modules",
      '-u'            => user,
      '-p'            => password
    }

    result = bolt_command_on(bolt, bolt_command, flags)
    winrm_nodes.each do |node|
      message = "Unexpected output from the command:\n#{result.cmd}"
      assert_match(/#{node.hostname.split('.')[0]}/, result.stdout, message)
      assert_match(/{#{node.ip}}/, result.stdout, message)
    end
  end
end
