test_name "C100550: \
           bolt task run should execute puppet task on remote hosts via ssh" do

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
    bolt_command = "bolt task run test::hostname_nix \
                      --nodes #{nodes_csv}           \
                      --modulepath #{dir}/modules    \
                      --user #{user}                 \
                      --password #{password}         \
                      --insecure"

    result = nil
    case bolt['platform']
    when /windows/
      result = on(bolt, powershell(bolt_command))
    else
      result = on(bolt, bolt_command)
    end
    ssh_nodes.each do |node|
      assert_match(/hello from #{node.hostname.split('.')[0]}/, result.stdout)
    end
  end
end
