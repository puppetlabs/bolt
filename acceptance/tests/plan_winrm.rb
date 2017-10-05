test_name "C100554: \
           bolt plan run executes puppet plan on remote hosts via winrm" do

  winrm_nodes = select_hosts(roles: ['winrm'])
  skip_test('no applicable nodes to test on') if winrm_nodes.empty?

  dir = bolt.tmpdir('C100554')

  testdir = winrm_nodes[0].tmpdir('C100554')
  step "create test dir on winrm nodes" do
    winrm_nodes.each do |node|
      on(node, "mkdir #{testdir}", acceptable_exit_codes: [0, 1])
    end
  end

  step "create plan on bolt controller" do
    on(bolt, "mkdir -p #{dir}/modules/test/{tasks,plans}")
    create_remote_file(bolt, "#{dir}/modules/test/tasks/a_win", <<-FILE)
    (echo "Line one from task a") > #{testdir}/C100554_plan_artifact.txt
    FILE
    create_remote_file(bolt, "#{dir}/modules/test/tasks/b_win", <<-FILE)
    (echo "Line two from task b") >> #{testdir}/C100554_plan_artifact.txt
    FILE
    create_remote_file(bolt,
                       "#{dir}/modules/test/plans/my_win_plan.pp", <<-FILE)
    plan test::my_win_plan($nodes) {
      $nodes_array = $nodes.split(',')
      run_task(Test::A_win, $nodes_array)
      run_task(Test::B_win, $nodes_array)
    }
    FILE
  end

  step "execute `bolt plan run` via WinRM" do
    user = ENV['WINRM_USER']
    password = ENV['WINRM_PASSWORD']
    nodes_csv = winrm_nodes.map { |host| "winrm://#{host.hostname}" }.join(',')
    bolt_command = "bolt plan run test::my_win_plan  \
                      nodes=#{nodes_csv}             \
                      --modulepath #{dir}/modules    \
                      --user #{user}                 \
                      --password #{password}"

    result = nil
    case bolt['platform']
    when /windows/
      result = on(bolt, powershell(bolt_command))
    else
      result = on(bolt, bolt_command)
    end
    assert_match(/ExecutionResult/, result.stdout)
    winrm_nodes.each do |node|
      on(node, powershell("type #{testdir}/C100554_plan_artifact.txt")) do |res|
        assert_match(/Line one from task a/, res.stdout)
        assert_match(/Line two from task b/, res.stdout)
      end
    end
  end
end
