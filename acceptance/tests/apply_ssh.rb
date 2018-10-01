# frozen_string_literal: true

require 'bolt_command_helper'
require 'json'

test_name "bolt plan run should apply manifest block on remote hosts via ssh" do
  extend Acceptance::BoltCommandHelper

  ssh_nodes = select_hosts(roles: ['ssh'])
  osx11 = select_hosts(platform: [/osx-10.11/])
  targets = "ssh_nodes"
  if osx11.any?
    ssh_nodes -= osx11
    targets = ssh_nodes.each_with_object([]) { |node, acc| acc.push(node[:vmhostname]) }.join(",")
  end

  skip_test('no applicable nodes to test on') if ssh_nodes.empty?

  dir = bolt.tmpdir('apply_ssh')
  fixtures = File.absolute_path('files')
  filepath = File.join('/tmp', SecureRandom.uuid.to_s)

  step "create plan on bolt controller" do
    on(bolt, "mkdir -p #{dir}/modules")
    scp_to(bolt, File.join(fixtures, 'example_apply'), "#{dir}/modules/example_apply")
  end

  bolt_command = "bolt plan run example_apply filepath=#{filepath} nodes=#{targets}"
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

      # Verify the custom type was invoked
      logs = result[0]['result']['report']['logs']
      warnings = logs.select { |l| l['level'] == 'warning' }
      assert_equal(1, warnings.count)
      assert_equal('Writing a MOTD!', warnings[0]['message'])

      # Verify that files were created on the target
      hello = on(node, "cat #{filepath}/hello.txt")
      assert_match(/^hi there I'm [a-zA-Z]+$/, hello.stdout)

      motd = on(node, "cat #{filepath}/motd")
      assert_equal("Today's #WordOfTheDay is 'gloss'", motd.stdout)
    end
  end

  step "puppet service should be stopped" do
    service_command = "bolt task run service action=status name=puppet -n #{targets}"
    result = bolt_command_on(bolt, service_command, flags)

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
      result = json['items'].select { |n| n['node'] == host }
      assert_equal('success', result[0]['status'],
                   "The task did not succeed on #{host}")

      assert_match(/stopped|absent/, result[0]['result']['status'], "Puppet must be stopped")
      assert_equal('false', result[0]['result']['enabled'], "Puppet must be disabled")
    end
  end

  step "apply as non-root user" do
    restricted_filepath = '/etc/puppetlabs/test'
    user = 'apply_nonroot'

    step 'create nonroot user on targets' do
      on(ssh_nodes, "/opt/puppetlabs/bin/puppet resource user #{user} ensure=present")

      teardown do
        on(ssh_nodes, "/opt/puppetlabs/bin/puppet resource user #{user} ensure=absent")
      end
    end

    step 'disable requiretty for root user' do
      linux_nodes = ssh_nodes.reject { |host| host['platform'] =~ /osx/ }
      create_remote_file(linux_nodes, "/etc/sudoers.d/#{user}", <<-FILE)
Defaults:root !requiretty
FILE

      teardown do
        on(linux_nodes, "rm /etc/sudoers.d/#{user}")
      end
    end

    bolt_command = "bolt plan run example_apply filepath=#{restricted_filepath} nodes=#{targets}"

    step "execute `bolt plan run run_as=#{user}` via SSH with json output" do
      result = bolt_command_on(bolt, bolt_command + " run_as=#{user}", flags)
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
                     "The task did not pass on #{host}")
        assert_match(/Permission denied/, result[0]['result']['report']['_error']['msg'])

        # Verify that files were not created on the target
        on(node, "cat #{restricted_filepath}/hello.txt", acceptable_exit_codes: [1])
      end
    end
  end
end
