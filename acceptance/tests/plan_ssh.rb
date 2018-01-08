require 'bolt_command_helper'
extend Acceptance::BoltCommandHelper

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
      notice("${run_task(test::a_unix, $nodes_array)}")
      notice("${run_task(test::b_unix, $nodes_array)}")
    }
    FILE
  end

  step "execute `bolt plan run` via SSH" do
    user = ENV['SSH_USER']
    password = ENV['SSH_PASSWORD']
    nodes_csv = ssh_nodes.map(&:hostname).join(',')
    bolt_command = "bolt plan run test::my_unix_plan nodes=#{nodes_csv}"

    flags = {
      '-u'            => user,
      '--modulepath'  => "#{dir}/modules",
      '-p'            => password,
      '--insecure'    => nil
    }

    result = bolt_command_on(bolt, bolt_command, flags)
    message = "The plan was expected to notify but did not"
    assert_match(/Notice:/, result.stdout, message)
    ssh_nodes.each do |node|
      message = "The plan was expceted to mention the host #{node.hostname} with _output"
      assert_match(/#{node.hostname}"=>{"_output"=>/, result.stdout, message)
    end

    ssh_nodes.each do |node|
      # bolt plan return value unspecified
      command = "cat /tmp/C100553_plan_artifact.txt"
      on(node, command, accept_all_exit_codes: true) do |res|
        cat_fail_msg = "The 'cat' command was not successful"
        assert_equal(res.exit_code, 0, cat_fail_msg)

        fail_msg = 'The observed contents of the plan artifact was unexpected'
        assert_match(/Line one from task a/, res.stdout, fail_msg)
        assert_match(/Line two from task b/, res.stdout, fail_msg)
      end
    end
  end
end
