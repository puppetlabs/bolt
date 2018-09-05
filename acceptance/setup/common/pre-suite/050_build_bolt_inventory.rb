# frozen_string_literal: true

require 'bolt_command_helper'
require 'bolt_setup_helper'

test_name "build bolt inventory file" do
  extend Acceptance::BoltCommandHelper
  extend Acceptance::BoltSetupHelper

  ssh_nodes = select_hosts(roles: ['ssh'])
  winrm_nodes = select_hosts(roles: ['winrm'])

  ssh_config = {
    'transport' => 'ssh',
    'ssh' => {
      'user' => ssh_user,
      'password' => ssh_password,
      'host-key-check' => false
    }
  }

  winrm_config = {
    'transport' => 'winrm',
    'winrm' => {
      'user' => winrm_user,
      'password' => winrm_password,
      'ssl' => false
    }
  }

  inventory = {
    'groups' => [
      { 'name' => 'ssh_nodes', 'nodes' => ssh_nodes.map(&:hostname), 'config' => ssh_config },
      { 'name' => 'winrm_nodes', 'nodes' => winrm_nodes.map(&:hostname), 'config' => winrm_config }
    ]
  }

  on bolt, "mkdir -p #{default_boltdir}"
  create_remote_file(bolt, "#{default_boltdir}/inventory.yaml", inventory.to_yaml)

  create_remote_file(bolt, "#{default_boltdir}/analytics.yaml", { 'disabled' => true }.to_yaml)
end
