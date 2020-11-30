# frozen_string_literal: true

require 'bolt_command_helper'
require 'json'

test_name "bolt plan run should apply manifest block on remote hosts via ssh" do
  extend Acceptance::BoltCommandHelper

  ssh_nodes = select_hosts(roles: ['ssh'])
  skip_targets = select_hosts(platform: [/debian-8/])
  targets = "ssh_nodes"
  if skip_targets.any?
    ssh_nodes -= skip_targets
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

  bolt_command = "bolt plan run example_apply filepath=#{filepath}"
  flags = {
    '--modulepath' => modulepath(File.join(dir, 'modules')),
    '--format' => 'json',
    '-t' => targets
  }

  teardown do
    on(ssh_nodes, "rm -rf #{filepath}")
  end

  step "execute `bolt plan run` via SSH with json output" do
    result = bolt_command_on(bolt, bolt_command, flags)
    assert_equal(0, result.exit_code,
                 "Bolt did not exit with exit code 0")

    begin
      json = JSON.parse(result.stdout)
    rescue JSON::ParserError
      assert_equal("Output should be JSON", result.string,
                   "Output should be JSON")
    end

    ssh_nodes.each do |node|
      # Verify that node succeeded
      host = node.hostname
      result = json.select { |n| n['target'] == host }
      assert_equal('success', result[0]['status'],
                   "The task did not succeed on #{host}")

      # Verify the custom type was invoked
      logs = result[0]['value']['report']['logs']
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
    service_command = "bolt plan run example_apply::puppet_status"
    result = bolt_command_on(bolt, service_command, flags)

    assert_equal(0, result.exit_code,
                 "Bolt did not exit with exit code 0")

    begin
      json = JSON.parse(result.stdout)
    rescue JSON::ParserError
      assert_equal("Output should be JSON", result.string,
                   "Output should be JSON")
    end

    ssh_nodes.each do |node|
      # Verify that node succeeded
      host = node.hostname
      result = json.select { |n| n['target'] == host }
      assert_equal('success', result[0]['status'],
                   "The task did not succeed on #{host}")

      assert_match(/stopped|absent/, result[0]['value']['status'], "Puppet must be stopped")
      assert_equal('false', result[0]['value']['enabled'], "Puppet must be disabled")
    end
  end

  step "apply as non-root user" do
    user = 'apply_nonroot'

    step 'create nonroot user on targets' do
      # managehome fails here, so we manage the homedir seprately
      on(ssh_nodes, "/opt/puppetlabs/bin/puppet resource user #{user} ensure=present")
      on(ssh_nodes, "/opt/puppetlabs/bin/puppet resource file $(echo ~#{user}) ensure=directory")

      teardown do
        on(ssh_nodes, "/opt/puppetlabs/bin/puppet resource file $(echo ~#{user}) ensure=absent")
        on(ssh_nodes, "/opt/puppetlabs/bin/puppet resource user #{user} ensure=absent")
      end
    end

    step 'create nonroot user-owned directory on targets' do
      filepath = "/tmp/mydir"
      on(ssh_nodes, "/opt/puppetlabs/bin/puppet resource file #{filepath} ensure=directory owner=#{user}")

      teardown do
        on(ssh_nodes, "/opt/puppetlabs/bin/puppet resource file #{filepath} ensure=absent")
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

    bolt_command = "bolt plan run example_apply filepath=#{filepath}"

    step "execute `bolt plan run run_as=#{user}` via SSH with json output" do
      result = bolt_command_on(bolt, bolt_command + " run_as=#{user}", flags)
      assert_equal(0, result.exit_code,
                   "Bolt did not exit with exit code 0")

      begin
        json = JSON.parse(result.stdout)
      rescue JSON::ParserError
        assert_equal("Output should be JSON", result.string,
                     "Output should be JSON")
      end

      ssh_nodes.each do |node|
        host = node.hostname
        result = json.select { |n| n['target'] == host }.first
        assert_equal('success', result['status'],
                     "The task failed on #{host}")

        stat = if node['platform'] =~ /osx/
                 "stat -f %Su #{filepath}/hello.txt"
               else
                 "stat -c %U #{filepath}/hello.txt"
               end
        owner_result = bolt_command_on(bolt, "bolt command run \"#{stat}\" -t #{host} --format json")
        # It's times like this I think I'm just a highly paid data parser
        owner = JSON.parse(owner_result.stdout)['items'].first['value']['stdout'].strip
        assert_equal(user, owner, "The file created in the apply block is not owned by the run_as user")
      end
    end
  end
end
