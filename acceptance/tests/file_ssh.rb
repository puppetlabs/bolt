# frozen_string_literal: true

require 'bolt_command_helper'

test_name "C1005xx: \
           bolt file upload should copy local file to remote hosts via ssh" do
  extend Acceptance::BoltCommandHelper

  ssh_nodes = select_hosts(roles: ['ssh'])
  skip_test('no applicable nodes to test on') if ssh_nodes.empty?

  dir = bolt.tmpdir('C1005xx')

  step "create file on bolt controller" do
    create_remote_file(bolt, "#{dir}/C1005xx_file.txt", <<-FILE)
    When in the course of human events it becomes necessary for one people...
    FILE
  end

  step "execute `bolt file upload` via SSH" do
    source = dest = 'C1005xx_file.txt'
    user = ENV['SSH_USER']
    password = ENV['SSH_PASSWORD']
    nodes_csv = ssh_nodes.map(&:hostname).join(',')
    bolt_command = "bolt file upload #{dir}/#{source} /tmp/#{dest}"
    flags = {
      '--nodes'              => nodes_csv,
      '--user'               => user,
      '--password'           => password,
      '--no-host-key-check'  => nil
    }

    result = bolt_command_on(bolt, bolt_command, flags)

    message = "Unexpected output from the command:\n#{result.cmd}"
    assert_match(/Uploaded.*#{source}.*to.*#{dest}/, result.stdout, message)

    ssh_nodes.each do |node|
      command = "cat /tmp/C1005xx_file.txt"
      on(node, command, accept_all_exit_codes: true) do |res|
        assert_equal(res.exit_code, 0, 'cat was not successful')

        file_contents_message = 'The expected file contents where not observed'
        regex = /When in the course of human events/
        assert_match(regex, res.stdout, file_contents_message)
      end
    end
  end
end
