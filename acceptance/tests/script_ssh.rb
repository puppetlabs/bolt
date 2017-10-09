test_name "C100548: \
           bolt script run should execute script on remote hosts via ssh" do

  ssh_nodes = select_hosts(roles: ['ssh'])
  skip_test('no applicable nodes to test on') if ssh_nodes.empty?

  script = "C100548.sh"

  step "create script on bolt controller" do
    create_remote_file(bolt, script, <<-FILE)
    #!/bin/sh
    echo "hello from $(hostname)"
    FILE
  end

  step "execute `bolt script run` via SSH" do
    user = ENV['SSH_USER']
    password = ENV['SSH_PASSWORD']
    nodes_csv = ssh_nodes.map(&:hostname).join(',')
    bolt_command = "bolt script run #{script} \
                    --nodes #{nodes_csv}      \
                    -u #{user} -p #{password} \
                    --insecure"

    result = nil
    case bolt['platform']
    when /windows/
      result = execute_powershell_script_on(bolt, bolt_command)
    when /osx/
      env = 'source /etc/profile  ~/.bash_profile ~/.bash_login ~/.profile && '
      result = on(bolt, env + bolt_command)
    else
      result = on(bolt, bolt_command)
    end
    ssh_nodes.each do |node|
      assert_match(/hello from #{node.hostname.split('.')[0]}/, result.stdout)
    end
  end
end
