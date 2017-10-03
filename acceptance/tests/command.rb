test_name "C100546: bolt command run should execute command on remote hosts via ssh" do
  step "execute `bolt command run` via SSH" do
    ssh_nodes = select_hosts({:roles => ['ssh']})
    nodes_csv = ssh_nodes.map { |host| host.hostname }.join(',')
    command = 'hostname -f'
    bolt_command = "bolt command run --nodes #{nodes_csv} '#{command}'"
    case bolt['platform']
    when /windows/
      execute_powershell_script_on(bolt, bolt_command)
    else
      on(bolt, bolt_command)
    end
  end
end
