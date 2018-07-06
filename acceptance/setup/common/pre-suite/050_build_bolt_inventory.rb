# frozen_string_literal: true

require 'bolt_setup_helper'

test_name "build bolt inventory file" do
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

  bolt_confdir = "#{on(bolt, 'echo $HOME').stdout.chomp}/.puppetlabs/bolt"

  on bolt, "mkdir -p #{bolt_confdir}"
  create_remote_file(bolt, "#{bolt_confdir}/inventory.yaml", inventory.to_yaml)

  create_remote_file(bolt, "#{bolt_confdir}/analytics.yaml", { 'disabled' => true }.to_yaml)
end
