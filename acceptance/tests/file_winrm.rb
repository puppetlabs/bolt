# frozen_string_literal: true

require 'bolt_command_helper'

test_name "C1005xx: \
           bolt file upload should copy local file to remote hosts via winrm" do
  extend Acceptance::BoltCommandHelper

  winrm_nodes = select_hosts(roles: ['winrm'])
  skip_test('no applicable nodes to test on') if winrm_nodes.empty?

  dir = bolt.tmpdir('C1005xx')

  testdir = winrm_nodes[0].tmpdir('C1005xx')
  step "create test dir on winrm nodes" do
    winrm_nodes.each do |node|
      on(node, "mkdir #{testdir}", acceptable_exit_codes: [0, 1])
    end
  end

  step "create file on bolt controller" do
    create_remote_file(bolt, "#{dir}/C1005xx_file.txt", <<-FILE)
    When in the course of human events it becomes necessary for one people...
    FILE
  end

  step "execute `bolt file upload` via WinRM" do
    source = dest = 'C1005xx_file.txt'
    user = ENV['WINRM_USER']
    password = ENV['WINRM_PASSWORD']
    nodes_csv = winrm_nodes.map { |host| "winrm://#{host.hostname}" }.join(',')
    bolt_command = "bolt file upload '#{dir}/#{source}' '#{testdir}/#{dest}'"

    flags = {
      '--nodes'     => nodes_csv,
      '-u'          => user,
      '-p'          => password,
      '--no-ssl'    => nil
    }

    result = bolt_command_on(bolt, bolt_command, flags)
    message = "Unexpected output from the command:\n#{result.cmd}"
    assert_match(/Uploaded.*#{source}.*to.*#{dest}/, result.stdout, message)

    winrm_nodes.each do |node|
      command = "type #{testdir}/C1005xx_file.txt"
      on(node, powershell(command), accept_all_exit_codes: true) do |res|
        type_message = "The powershell command 'type' was not successful"
        assert_equal(res.exit_code, 0, type_message)

        content_message = "The content of the file upload was unexpected"
        regex = /When in the course of human events/
        assert_match(regex, res.stdout, content_message)
      end
    end
  end
end
