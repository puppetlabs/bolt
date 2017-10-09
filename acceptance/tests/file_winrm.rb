test_name "C1005xx: \
           bolt file upload should copy local file to remote hosts via winrm" do

  winrm_nodes = select_hosts(roles: ['winrm'])
  skip_test('no applicable nodes to test on') if winrm_nodes.empty?

  dir = bolt.tmpdir('C1005xx')

  testdir = winrm_nodes[0].tmpdir('C1005xx')
  step "create test dir on winrm nodes" do
    winrm_nodes.each do |node|
      on(node, "mkdir #{testdir}", acceptable_exit_codes: [0, 1])
    end
  end

  step "create file on bolt controller" do
    create_remote_file(bolt, "#{dir}/C1005xx_file.txt", <<-FILE)
    When in the course of human events it becomes necessary for one people...
    FILE
  end

  step "execute `bolt file upload` via WinRM" do
    source = dest = 'C1005xx_file.txt'
    user = ENV['WINRM_USER']
    password = ENV['WINRM_PASSWORD']
    nodes_csv = winrm_nodes.map { |host| "winrm://#{host.hostname}" }.join(',')
    bolt_command = "bolt file upload                 \
                      '#{dir}/#{source}' '#{testdir}/#{dest}'   \
                      --nodes #{nodes_csv}           \
                      --user #{user}                 \
                      --password #{password}"

    result = nil
    case bolt['platform']
    when /windows/
      result = on(bolt, powershell(bolt_command))
    else
      result = on(bolt, bolt_command)
    end
    assert_match(/Uploaded.*#{source}.*to.*#{dest}/, result.stdout)
    winrm_nodes.each do |node|
      on(node, powershell("type #{testdir}/C1005xx_file.txt")) do |res|
        assert_match(/When in the course of human events/, res.stdout)
      end
    end
  end
end
