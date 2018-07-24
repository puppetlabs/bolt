# frozen_string_literal: true

require 'bolt_command_helper'
require 'json'

test_name "bolt plan run with should apply manifest block on remote hosts via ssh" do
  extend Acceptance::BoltCommandHelper

  ssh_nodes = select_hosts(roles: ['ssh'])
  skip_test('no applicable nodes to test on') if ssh_nodes.empty?

  dir = bolt.tmpdir('apply_ssh')
  fixtures = File.absolute_path('files')
  filepath = '/tmp/test'

  step "create plan on bolt controller" do
    on(bolt, "mkdir -p #{dir}/modules/example_apply/plans")
    create_remote_file(bolt,
                       "#{dir}/modules/example_apply/plans/init.pp",
                       File.read(File.join(fixtures, 'example_apply.pp')))
  end

  bolt_command = "bolt plan run example_apply filepath=#{filepath} nodes=ssh_nodes"
  flags = {
    '--modulepath' => modulepath(File.join(dir, 'modules')),
    '--format'     => 'json'
  }

  teardown do
    on(ssh_nodes, "rm -rf #{filepath}")
  end

  step "execute `bolt plan run noop=true` via SSH with json output" do
    result = bolt_command_on(bolt, bolt_command + ' noop=true', flags)
    assert_equal(0, result.exit_code,
                 "Bolt did not exit with exit code 0")

    begin
      json = JSON.parse(result.stdout)
    rescue JSON.ParserError
      assert_equal("Output should be JSON", result.string,
                   "Output should be JSON")
    end

    ssh_nodes.each do |node|
      # Verify that node succeeded
      host = node.hostname
      result = json.select { |n| n['node'] == host }
      assert_equal('success', result[0]['status'],
                   "The task did not succeed on #{host}")

      # Verify that files were not created on the target
      on(node, "cat #{filepath}/hello.txt", acceptable_exit_codes: [1])
    end
  end

  step "execute `bolt plan run` via SSH with json output" do
    result = bolt_command_on(bolt, bolt_command, flags)
    assert_equal(0, result.exit_code,
                 "Bolt did not exit with exit code 0")

    begin
      json = JSON.parse(result.stdout)
    rescue JSON.ParserError
      assert_equal("Output should be JSON", result.string,
                   "Output should be JSON")
    end

    ssh_nodes.each do |node|
      # Verify that node succeeded
      host = node.hostname
      result = json.select { |n| n['node'] == host }
      assert_equal('success', result[0]['status'],
                   "The task did not succeed on #{host}")

      # Verify that files were created on the target
      content = on(node, "cat #{filepath}/hello.txt")
      assert_match(/^hi there I'm [a-zA-Z]+$/, content.stdout)
    end
  end
end
