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

  on bolt, 'mkdir -p ~/.puppetlabs/bolt'
  create_remote_file(bolt, "/root/.puppetlabs/bolt/inventory.yaml", inventory.to_yaml)
end
