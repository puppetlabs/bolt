require 'bolt_command_helper'
extend Acceptance::BoltCommandHelper

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
    create_remote_file(bolt, "#{dir}/modules/test/tasks/a_win.ps1", <<-FILE)
    (echo "Line one from task a") > #{testdir}/C100554_plan_artifact.txt
    FILE
    create_remote_file(bolt, "#{dir}/modules/test/tasks/b_win.ps1", <<-FILE)
    (echo "Line two from task b") >> #{testdir}/C100554_plan_artifact.txt
    FILE
    create_remote_file(bolt,
                       "#{dir}/modules/test/plans/my_win_plan.pp", <<-FILE)
    plan test::my_win_plan($nodes) {
      $nodes_array = $nodes.split(',')
      notice("${run_task(test::a_win, $nodes_array)}")
      notice("${run_task(test::b_win, $nodes_array)}")
    }
    FILE
  end

  step "execute `bolt plan run` via WinRM" do
    user = ENV['WINRM_USER']
    password = ENV['WINRM_PASSWORD']
    nodes_csv = winrm_nodes.map { |host| "winrm://#{host.hostname}" }.join(',')
    bolt_command = "bolt plan run test::my_win_plan nodes=#{nodes_csv}"

    flags = {
      '--modulepath'  => "#{dir}/modules",
      '-u'            => user,
      '-p'            => password,
      '--insecure'    => nil
    }

    result = bolt_command_on(bolt, bolt_command, flags)
    message = "The plan was expected to notify but did not"
    assert_match(/Notice:/, result.stdout, message)
    winrm_nodes.each do |node|
      message = "The plan was expceted to mention the host #{node.hostname} with _output"
      assert_match(/#{node.hostname}"=>{"_output"=>/, result.stdout, message)
    end

    winrm_nodes.each do |node|
      command = "type #{testdir}/C100554_plan_artifact.txt"
      on(node, powershell(command), accept_all_exit_codes: true) do |res|
        type_msg = "The powershell command 'type' was not successful"
        assert_equal(res.exit_code, 0, type_msg)

        msg = 'The expected contents of the plan artifact were not observed'
        assert_match(/Line one from task a/, res.stdout, msg)
        assert_match(/Line two from task b/, res.stdout, msg)
      end
    end
  end
end
