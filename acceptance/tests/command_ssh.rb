# frozen_string_literal: true

require 'bolt_command_helper'

test_name "C100546: \
           bolt command run should execute command on remote hosts via ssh" do
  extend Acceptance::BoltCommandHelper

  ssh_nodes = select_hosts(roles: ['ssh'])
  skip_test('no applicable nodes to test on') if ssh_nodes.empty?

  step "execute `bolt command run` via SSH" do
    command = 'echo """hello from $(hostname)"""'
    bolt_command = "bolt command run '#{command}'"
    flags = { '--nodes' => 'ssh_nodes' }

    result = bolt_command_on(bolt, bolt_command, flags)

    ssh_nodes.each do |node|
      message = "Unexpected output from the command:\n#{result.cmd}"
      regex = /hello from #{node.hostname.split('.')[0]}/
      assert_match(regex, result.stdout, message)
    end
  end
end
