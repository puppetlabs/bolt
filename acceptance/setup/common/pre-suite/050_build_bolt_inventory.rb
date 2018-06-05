# frozen_string_literal: true

test_name "build bolt inventory file" do
  ssh_nodes = select_hosts(roles: ['ssh'])
  winrm_nodes = select_hosts(roles: ['winrm'])

  ssh_config = {
    'transport' => 'ssh',
    'ssh' => {
      'user' => ENV['SSH_USER'],
      'password' => ENV['SSH_PASSWORD'],
      'host-key-check' => false
    }
  }
  winrm_config = {
    'transport' => 'winrm',
    'winrm' => {
      'user' => ENV['WINRM_USER'],
      'password' => ENV['WINRM_PASSWORD'],
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
