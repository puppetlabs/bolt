# frozen_string_literal: true

require 'bolt_command_helper'

test_name "C100554: \
           bolt plan run executes puppet plan on remote hosts via winrm" do
  extend Acceptance::BoltCommandHelper

  winrm_nodes = select_hosts(roles: ['winrm'])
  skip_test('no applicable nodes to test on') if winrm_nodes.empty?

  first_node = winrm_nodes[0].hostname.split('.')[0].upcase

  dir = bolt.tmpdir('C100554')

  testdir = winrm_nodes[0].tmpdir('C100554')

  step "create test dir on winrm nodes" do
    winrm_nodes.each do |node|
      on(node, "mkdir #{testdir}", acceptable_exit_codes: [0, 1])
    end
  end

  step "create task on bolt controller" do
    on(bolt, "mkdir -p #{dir}/modules/test/{tasks,plans}")
    create_remote_file(bolt, "#{dir}/modules/test/tasks/hostname.ps1", <<-FILE)
if (!(Test-Path c:\\tmp\\retry.txt) -and ($env:computername -eq "#{first_node}")) {
  ni c:\\tmp\\retry.txt -type file -force
  exit 1
}
elseif (Test-Path c:\\tmp\\retry.txt) {
  ri c:\\tmp\\retry.txt
}
    FILE
  end

  step "create plan on bolt controller" do
    create_remote_file(bolt,
                       "#{dir}/modules/test/plans/winrm_retry_plan.pp", <<-FILE)
plan test::winrm_retry_plan($nodes) {
  $node_array = $nodes.split(',')
  $result = run_task(test::hostname, $node_array,
        '_catch_errors' =>true)
  $retry = run_task(test::hostname, $result.error_set.names)
  return({ 'result' => $result, 'retry' => $retry })
}
    FILE
  end

  step "execute `bolt plan run` via WinRM with json output" do
    bolt_command = "bolt plan run test::winrm_retry_plan nodes=winrm_nodes"
    flags = {
      '--modulepath' => "#{dir}/modules",
      '--format' => 'json'
    }

    result = bolt_command_on(bolt, bolt_command, flags)
    assert_equal(0, result.exit_code,
                 "Bolt did not exit with exit code 0")

    begin
      json = JSON.parse(result.stdout)
    rescue JSON::ParserError
      assert_equal("Output should be JSON", result.string,
                   "Output should be JSON")
    end

    # Verify that the first node failed on the first run
    failed_node = json['result'].select { |n| n['status'] == 'failure' }
    assert(!failed_node.empty?, "No nodes failed on the first task run")
    assert(failed_node.length < 2, "More than 1 node failed the first task run")
    assert_equal(winrm_nodes[0].hostname, failed_node[0]['node'],
                 "The hostname #{winrm_nodes[0].hostname} is not correct")

    # Verify that the second node succeeded on the first run
    if winrm_nodes.length > 1
      winrm_nodes[1..-1].each do |node|
        host = node.hostname
        result = json['result'].select { |n| n['node'] == host }
        assert_equal('success', result[0]['status'],
                     "The task did not succeed on #{node.hostname}")
      end
    else
      logger.warn("There were not enough nodes to verify that some nodes succeeded")
    end

    # Verify that the retry run succeeded with expected nodes
    assert_equal(1, json['retry'].length, "More than 1 node was retried")
    assert_equal(winrm_nodes[0].hostname, json['retry'][0]['node'],
                 "The retry run did not run on #{winrm_nodes[0].hostname}")
    assert_equal('success', json['retry'][0]['status'],
                 "The retry run did not succeed")
  end

  step "execute `bolt plan run` via WinRM with verbose, human readable output" do
    bolt_command = "bolt plan run test::winrm_retry_plan nodes=winrm_nodes"
    flags = {
      '--modulepath' => "#{dir}/modules",
      '--verbose' => nil
    }

    result = bolt_command_on(bolt, bolt_command, flags)

    assert_match(/Starting: task test::hostname/, result.output,
                 "The starting task message was not in the output")
    assert_match(/Finished: task test::hostname/, result.output,
                 "The ran task message was not in the output")
    assert_match(/with 1 failure/, result.output,
                 "Node failure was not logged correctly")
  end
end
