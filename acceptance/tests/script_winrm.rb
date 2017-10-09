test_name "C100549: \
           bolt script run should execute script on remote hosts via winrm" do

  winrm_nodes = select_hosts(roles: ['winrm'])
  skip_test('no applicable nodes to test on') if winrm_nodes.empty?

  script = "C100549.ps1"

  step "create script on bolt controller" do
    create_remote_file(bolt, script, <<-FILE)
    [System.Net.Dns]::GetHostByName(($env:computerName))
    FILE
  end

  step "execute `bolt script run` via WinRM" do
    user = ENV['WINRM_USER']
    password = ENV['WINRM_PASSWORD']
    nodes_csv = winrm_nodes.map { |host| "winrm://#{host.hostname}" }.join(',')
    bolt_command = "bolt script run #{script} \
                    --nodes #{nodes_csv}      \
                    -u #{user} -p #{password}"

    result = nil
    case bolt['platform']
    when /windows/
      result = on(bolt, powershell(bolt_command))
    when /osx/
      env = 'source /etc/profile  ~/.bash_profile ~/.bash_login ~/.profile && '
      result = on(bolt, env + bolt_command)
    else
      result = on(bolt, bolt_command)
    end
    winrm_nodes.each do |node|
      assert_match(/#{node.hostname.split('.')[0]}/, result.stdout)
      assert_match(/{#{node.ip}}/, result.stdout)
    end
  end
end
