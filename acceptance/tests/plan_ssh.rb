test_name "C100553: \
           bolt plan run should execute puppet plan on remote hosts via ssh" do

  ssh_nodes = select_hosts(roles: ['ssh'])
  skip_test('no applicable nodes to test on') if ssh_nodes.empty?

  dir = bolt.tmpdir('C100553')

  step "create plan on bolt controller" do
    on(bolt, "mkdir -p #{dir}/modules/test/{tasks,plans}")
    create_remote_file(bolt, "#{dir}/modules/test/tasks/a_unix", <<-FILE)
    echo "Line one from task a" > /tmp/C100553_plan_artifact.txt
    FILE
    create_remote_file(bolt, "#{dir}/modules/test/tasks/b_unix", <<-FILE)
    echo "Line two from task b" >> /tmp/C100553_plan_artifact.txt
    FILE
    create_remote_file(bolt,
                       "#{dir}/modules/test/plans/my_unix_plan.pp", <<-FILE)
    plan test::my_unix_plan($nodes) {
      $nodes_array = $nodes.split(',')
      run_task(Test::A_unix(), $nodes_array)
      run_task(Test::B_unix(), $nodes_array)
    }
    FILE
  end

  step "execute `bolt plan run` via SSH" do
    user = ENV['SSH_USER']
    password = ENV['SSH_PASSWORD']
    nodes_csv = ssh_nodes.map(&:hostname).join(',')
    bolt_command = "bolt plan run test::my_unix_plan \
                      nodes=#{nodes_csv}             \
                      --modulepath #{dir}/modules    \
                      --user #{user}                 \
                      --password #{password}         \
                      --insecure"

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
    assert_match(/ExecutionResult/, result.stdout)
    ssh_nodes.each do |node|
      # bolt plan return value unspecified
      on(node, "cat /tmp/C100553_plan_artifact.txt") do |res|
        assert_match(/Line one from task a/, res.stdout)
        assert_match(/Line two from task b/, res.stdout)
      end
    end
  end
end
