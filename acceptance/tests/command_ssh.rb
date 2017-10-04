test_name "C100546: \
           bolt command run should execute command on remote hosts via ssh" do

  ssh_nodes = select_hosts(roles: ['ssh'])
  skip_test('no applicable nodes to test on') if ssh_nodes.empty?

  step "execute `bolt command run` via SSH" do
    user = ENV['SSH_USER']
    password = ENV['SSH_PASSWORD']
    nodes_csv = ssh_nodes.map(&:hostname).join(',')
    command = 'echo """hello from $(hostname)"""'
    bolt_command = "bolt command run '#{command}' \
                    --nodes #{nodes_csv}          \
                    -u #{user} -p #{password}     \
                    --insecure"

    result = nil
    case bolt['platform']
    when /windows/
      result = execute_powershell_script_on(bolt, bolt_command)
    else
      result = on(bolt, bolt_command)
    end
    ssh_nodes.each do |node|
      assert_match(/hello from #{node.hostname.split('.')[0]}/, result.stdout)
    end
  end
end
