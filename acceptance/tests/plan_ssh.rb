# frozen_string_literal: true

require 'bolt_command_helper'
require 'json'

test_name "C100553: \
           bolt plan run should execute puppet plan on remote hosts via ssh" do
  extend Acceptance::BoltCommandHelper

  ssh_nodes = select_hosts(roles: ['ssh'])
  skip_test('no applicable nodes to test on') if ssh_nodes.empty?

  first_node = ssh_nodes[0].hostname.split('.')[0]

  dir = bolt.tmpdir('C100553')

  step 'create task on bolt controller' do
    on(bolt, "mkdir -p #{dir}/modules/test/{tasks,plans}")
    create_remote_file(bolt, "#{dir}/modules/test/tasks/hostname_nix.sh", <<-FILE)
#!/bin/bash
if [ ! -f /tmp/retry.txt ] && [ "$HOSTNAME" = '#{first_node}' ]; then
  touch /tmp/retry.txt;
  exit 1
elif [ -f /tmp/retry.txt ]; then
  rm /tmp/retry.txt
fi
    FILE
  end

  step "create plan on bolt controller" do
    create_remote_file(bolt,
                       "#{dir}/modules/test/plans/ssh_retry_plan.pp", <<-FILE)
plan test::ssh_retry_plan($nodes) {
  $node_array = $nodes.split(',')
  $result = run_task(test::hostname_nix, $node_array,
        '_catch_errors' =>true)
  $retry = run_task(test::hostname_nix, $result.error_set.names)
  return({ 'result' => $result, 'retry' => $retry })
}
    FILE
  end

  step "execute `bolt plan run` via SSH with json output" do
    bolt_command = "bolt plan run test::ssh_retry_plan nodes=ssh_nodes"
    flags = {
      '--modulepath' => "#{dir}/modules",
      '--format'     => 'json',
    }

    result = bolt_command_on(bolt, bolt_command, flags)
    assert_equal(0, result.exit_code,
                 "Bolt did not exit with exit code 0")

    begin
      json = JSON.parse(result.stdout)
    rescue JSON.ParserError
      assert_equal("Output should be JSON", result.string,
                   "Output should be JSON")
    end

    # Verify that the first node failed on the first run
    failed_node = json['result'].select { |n| n['status'] == 'failure' }
    assert(!failed_node.empty?, "No nodes failed on the first task run")
    assert(failed_node.length < 2, "More than 1 node failed the first task run")
    assert_equal(ssh_nodes[0].hostname, failed_node[0]['node'],
                 "The hostname #{ssh_nodes[0].hostname} is not correct")

    # Verify that all other nodes succeeded
    if ssh_nodes.length > 1
      ssh_nodes[1..-1].each do |node|
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
    assert_equal(ssh_nodes[0].hostname, json['retry'][0]['node'],
                 "The retry run did not run on #{ssh_nodes[0].hostname}")
    assert_equal('success', json['retry'][0]['status'],
                 "The retry run did not succeed")
  end

  step "execute `bolt plan run` via SSH with verbose, human readable output" do
    bolt_command = "bolt plan run test::ssh_retry_plan nodes=ssh_nodes"
    flags = {
      '--modulepath' => "#{dir}/modules",
      '--verbose'    => nil
    }

    result = bolt_command_on(bolt, bolt_command, flags)
    assert_match(/Bolt::Executor: Starting task/, result.output,
                 "The starting task message was not in the output")
    assert_match(/Bolt::Executor: Ran task/, result.output,
                 "The ran task message was not in the output")
    assert_match(/on #{ssh_nodes.length} node[s]? with 1 failure/, result.output,
                 "Task run failure was not logged correctly")
  end
end
