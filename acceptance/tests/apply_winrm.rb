# frozen_string_literal: true

require 'bolt_command_helper'
require 'json'

test_name "bolt plan run with should apply manifest block on remote hosts via winrm" do
  extend Acceptance::BoltCommandHelper

  winrm_nodes = select_hosts(roles: ['winrm'])
  skip_test('no applicable nodes to test on') if winrm_nodes.empty?

  controller_has_ruby = on(bolt, 'which ruby', accept_all_exit_codes: true).exit_code == 0
  skip_test('FIX: apply uses wrong Ruby') if controller_has_ruby && bolt[:roles].include?('winrm')

  dir = bolt.tmpdir('apply_winrm')
  fixtures = File.absolute_path('files')
  filepath = 'C:/test'

  step "create plan on bolt controller" do
    on(bolt, "mkdir -p #{dir}/modules/example_apply/plans")
    create_remote_file(bolt,
                       "#{dir}/modules/example_apply/plans/init.pp",
                       File.read(File.join(fixtures, 'example_apply.pp')))
  end

  bolt_command = "bolt plan run example_apply filepath=#{filepath} nodes=winrm_nodes"
  flags = {
    '--modulepath' => modulepath(File.join(dir, 'modules')),
    '--format'     => 'json'
  }

  step "execute `bolt plan run noop=true` via WinRM with json output" do
    on(winrm_nodes, "rm -rf #{filepath}")

    result = bolt_command_on(bolt, bolt_command + ' noop=true', flags)
    assert_equal(0, result.exit_code,
                 "Bolt did not exit with exit code 0")

    begin
      json = JSON.parse(result.stdout)
    rescue JSON.ParserError
      assert_equal("Output should be JSON", result.string,
                   "Output should be JSON")
    end

    winrm_nodes.each do |node|
      # Verify that node succeeded
      host = node.hostname
      result = json.select { |n| n['node'] == host }
      assert_equal('success', result[0]['status'],
                   "The task did not succeed on #{host}")

      # Verify that files were not created on the target
      on(node, "cat #{filepath}/hello.txt", acceptable_exit_codes: [1])
    end
  end

  step "execute `bolt plan run` via WinRM with json output" do
    result = bolt_command_on(bolt, bolt_command, flags)
    assert_equal(0, result.exit_code,
                 "Bolt did not exit with exit code 0")

    begin
      json = JSON.parse(result.stdout)
    rescue JSON.ParserError
      assert_equal("Output should be JSON", result.string,
                   "Output should be JSON")
    end

    winrm_nodes.each do |node|
      # Verify that node succeeded
      host = node.hostname
      result = json.select { |n| n['node'] == host }
      assert_equal('success', result[0]['status'],
                   "The task did not succeed on #{host}")

      # Verify that files were created on the target
      content = on(node, 'cat C:/test/hello.txt')
      assert_match(/^hi there I'm windows$/, content.stdout)
    end
  end
end
