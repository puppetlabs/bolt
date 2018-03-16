# frozen_string_literal: true

require 'bolt_command_helper'

test_name "C100550: \
           bolt task run should execute puppet task on remote hosts via ssh" do
  extend Acceptance::BoltCommandHelper

  ssh_nodes = select_hosts(roles: ['ssh'])
  skip_test('no applicable nodes to test on') if ssh_nodes.empty?

  dir = bolt.tmpdir('C100550')

  step "create task on bolt controller" do
    on(bolt, "mkdir -p #{dir}/modules/test/tasks")
    create_remote_file(bolt, "#{dir}/modules/test/tasks/hostname_nix", <<-FILE)
    echo "hello from $(hostname)"
    FILE
  end

  step "execute `bolt task run` via SSH" do
    user = ENV['SSH_USER']
    password = ENV['SSH_PASSWORD']
    nodes_csv = ssh_nodes.map(&:hostname).join(',')
    bolt_command = "bolt task run test::hostname_nix"
    flags = {
      '--nodes'                => nodes_csv,
      '--modulepath'           => "#{dir}/modules",
      '-u'                     => user,
      '-p'                     => password,
      '--no-host-key-check'    => nil
    }

    result = bolt_command_on(bolt, bolt_command, flags)
    ssh_nodes.each do |node|
      message = "Unexpected output from the command:\n#{result.cmd}"
      regex = /hello from #{node.hostname.split('.')[0]}/
      assert_match(regex, result.stdout, message)
    end
  end
end
