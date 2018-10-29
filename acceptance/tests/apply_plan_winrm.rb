# frozen_string_literal: true

require 'bolt_command_helper'
require 'json'

test_name "bolt plan run should apply manifest block on remote hosts via winrm" do
  extend Acceptance::BoltCommandHelper

  winrm_nodes = select_hosts(roles: ['winrm'])
  skip_test('no applicable nodes to test on') if winrm_nodes.empty?

  controller_has_ruby = on(bolt, 'which ruby', accept_all_exit_codes: true).exit_code == 0
  skip_test('FIX: apply uses wrong Ruby') if controller_has_ruby && bolt[:roles].include?('winrm')

  dir = bolt.tmpdir('apply_winrm')
  fixtures = File.absolute_path('files')
  filepath = File.join('C:/', SecureRandom.uuid.to_s)

  step "create plan on bolt controller" do
    on(bolt, "mkdir -p #{dir}/modules")
    scp_to(bolt, File.join(fixtures, 'example_apply'), "#{dir}/modules/example_apply")
  end

  bolt_command = "bolt plan run example_apply filepath=#{filepath} nodes=winrm_nodes"
  flags = {
    '--modulepath' => modulepath(File.join(dir, 'modules')),
    '--format' => 'json'
  }

  teardown do
    on(winrm_nodes, "rm -rf #{filepath}")
  end

  step "execute `bolt plan run noop=true` via WinRM with json output" do
    result = bolt_command_on(bolt, bolt_command + ' noop=true', flags)
    assert_equal(0, result.exit_code,
                 "Bolt did not exit with exit code 0")

    begin
      json = JSON.parse(result.stdout)
    rescue JSON::ParserError
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
    rescue JSON::ParserError
      assert_equal("Output should be JSON", result.string,
                   "Output should be JSON")
    end

    winrm_nodes.each do |node|
      # Verify that node succeeded
      host = node.hostname
      result = json.select { |n| n['node'] == host }
      assert_equal('success', result[0]['status'],
                   "The task did not succeed on #{host}")

      # Verify the custom type was invoked
      logs = result[0]['result']['report']['logs']
      warnings = logs.select { |l| l['level'] == 'warning' }
      assert_equal(1, warnings.count)
      assert_equal('Writing a MOTD!', warnings[0]['message'])

      # Verify that files were created on the target
      hello = on(node, "cat #{filepath}/hello.txt")
      assert_match(/^hi there I'm windows$/, hello.stdout)

      motd = on(node, "cat #{filepath}/motd")
      assert_equal("Today's #WordOfTheDay is 'gloss'", motd.stdout)
    end
  end

  step "puppet service should be stopped" do
    service_command = 'bolt task run service action=status name=puppet -n winrm_nodes'
    flags = { '--format' => 'json' }
    result = bolt_command_on(bolt, service_command, flags)

    assert_equal(0, result.exit_code,
                 "Bolt did not exit with exit code 0")

    begin
      json = JSON.parse(result.stdout)
    rescue JSON::ParserError
      assert_equal("Output should be JSON", result.string,
                   "Output should be JSON")
    end

    winrm_nodes.each do |node|
      # Verify that node succeeded
      host = node.hostname
      result = json['items'].select { |n| n['node'] == host }
      assert_equal('success', result[0]['status'],
                   "The task did not succeed on #{host}")

      assert_equal('stopped', result[0]['result']['status'], "Puppet must be stopped")
      assert_equal('false', result[0]['result']['enabled'], "Puppet must be disabled")
    end
  end
end
