test_name "C100551: \
           bolt task run executes puppet task on remote hosts via winrm" do

  winrm_nodes = select_hosts(roles: ['winrm'])
  skip_test('no applicable nodes to test on') if winrm_nodes.empty?

  dir = bolt.tmpdir('C100551')

  step "create task on bolt controller" do
    on(bolt, "mkdir -p #{dir}/modules/test/tasks")
    create_remote_file(bolt, "#{dir}/modules/test/tasks/hostname_win", <<-FILE)
    [System.Net.Dns]::GetHostByName(($env:computerName))
    FILE
  end

  step "execute `bolt task run` via WinRM" do
    user = ENV['WINRM_USER']
    password = ENV['WINRM_PASSWORD']
    nodes_csv = winrm_nodes.map { |host| "winrm://#{host.hostname}" }.join(',')
    bolt_command = "bolt task run test::hostname_win \
                      --nodes #{nodes_csv}           \
                      --modulepath #{dir}/modules    \
                      --user #{user}                 \
                      --password #{password}"

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
