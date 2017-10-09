test_name "C1005xx: \
           bolt file upload should copy local file to remote hosts via ssh" do

  ssh_nodes = select_hosts(roles: ['ssh'])
  skip_test('no applicable nodes to test on') if ssh_nodes.empty?

  dir = bolt.tmpdir('C1005xx')

  step "create file on bolt controller" do
    create_remote_file(bolt, "#{dir}/C1005xx_file.txt", <<-FILE)
    When in the course of human events it becomes necessary for one people...
    FILE
  end

  step "execute `bolt file upload` via SSH" do
    source = dest = 'C1005xx_file.txt'
    user = ENV['SSH_USER']
    password = ENV['SSH_PASSWORD']
    nodes_csv = ssh_nodes.map(&:hostname).join(',')
    bolt_command = "bolt file upload #{dir}/#{source} /tmp/#{dest}  \
                      --nodes #{nodes_csv}           \
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
    assert_match(/Uploaded.*#{source}.*to.*#{dest}/, result.stdout)
    ssh_nodes.each do |node|
      on(node, "cat /tmp/C1005xx_file.txt") do |res|
        assert_match(/When in the course of human events/, res.stdout)
      end
    end
  end
end
