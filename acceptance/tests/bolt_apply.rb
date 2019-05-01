# frozen_string_literal: true

require 'bolt_command_helper'
require 'json'

test_name "bolt apply should apply manifest block on remote hosts via ssh and winrm" do
  extend Acceptance::BoltCommandHelper

  ssh_nodes = select_hosts(roles: ['ssh'])
  winrm_nodes = select_hosts(roles: ['winrm'])
  targets = ssh_nodes + winrm_nodes

  # Puppet 6 doesn't support OSX 10.11, so skip those hosts if present
  targets -= select_hosts(platform: [/osx-10.11/, /osx-10.14/])

  skip_test('no applicable nodes to test on') if targets.empty?

  def check_result(result, targets)
    assert_equal(0, result.exit_code,
                 "Bolt did not exit with exit code 0")

    begin
      json = JSON.parse(result.stdout)
    rescue JSON::ParserError
      assert_equal("Output should be JSON", result.string,
                   "Output should be JSON")
    end

    targets.each do |node|
      # Verify that node succeeded
      host = node == 'localhost' ? 'localhost' : node.hostname
      result = json.find { |n| n['node'] == host }
      assert_equal('success', result['status'],
                   "The task did not succeed on #{host}")

      # Verify the notify was processed
      assert_includes(result.dig('result', 'report', 'resource_statuses'), 'Notify[hello world]')
    end
  end

  step "execute `bolt apply -e <code>` with json output" do
    bolt_command = "bolt apply -e \"notify { 'hello world': }\" --nodes #{targets.join(',')}"
    flags = {
      '--format' => 'json'
    }

    result = bolt_command_on(bolt, bolt_command, flags)
    check_result(result, targets)
  end

  step "execute `bolt apply -e <code>` with json output against localhost" do
    # TODO: Execute with '--run-as local_user' when BOLT-1283 is fixed
    bolt_command = "bolt apply -e \"notify { 'hello world': }\" --nodes localhost"
    flags = {
      '--format' => 'json'
    }

    result = bolt_command_on(bolt, bolt_command, flags)
    check_result(result, ['localhost'])
  end

  step "execute `bolt apply <file.pp>` with json output" do
    dir = bolt.tmpdir('bolt_apply')
    create_remote_file(bolt, "#{dir}/test.pp", <<-MANIFEST)
    notify { "hello world": }
    MANIFEST

    bolt_command = "bolt apply '#{dir}/test.pp' --nodes #{targets.join(',')}"
    flags = {
      '--format' => 'json'
    }

    result = bolt_command_on(bolt, bolt_command, flags)
    check_result(result, targets)
  end
end
