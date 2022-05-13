# frozen_string_literal: true

require 'bolt_command_helper'
require 'bolt_setup_helper'

test_name "Bolt file upload should copy local file to remote hosts via ssh" do
  extend Acceptance::BoltCommandHelper
  extend Acceptance::BoltSetupHelper

  skip_test('no applicable nodes to test on') if bolt['platform'] =~ /windows/

  dir = bolt.tmpdir('local_file_upload')

  step "create file on bolt controller" do
    create_remote_file(bolt, "#{dir}/local_file.txt", <<-FILE)
    When in the course of human events it becomes necessary for one people...
    FILE
  end

  step "execute `bolt file upload` via local transport" do
    source = dest = 'local_file.txt'
    bolt_command = "bolt file upload #{dir}/#{source} /tmp/#{dest}"
    flags = { '--targets' => 'localhost' }
    result = bolt_command_on(bolt, bolt_command, flags)

    message = "Unexpected output from the command:\n#{result.cmd}"
    assert_match(/Uploaded.*#{source}.*to.*#{dest}/, result.stdout, message)

    command = "cat /tmp/local_file.txt"
    on(bolt, command, accept_all_exit_codes: true) do |res|
      assert_equal(res.exit_code, 0, 'cat was not successful')

      file_contents_message = 'The expected file contents where not observed'
      regex = /When in the course of human events/
      assert_match(regex, res.stdout, file_contents_message)
    end
  end

  step "execute `bolt file upload` via local transport with run-as" do
    source = dest = 'local_file.txt'
    on(bolt, "cp #{dir}/#{source} #{local_user_homedir}/#{source}")
    on(bolt, "chown #{local_user} #{local_user_homedir}/#{source}")
    # previous test has root-owned copy, local user cannot overwrite it
    on(bolt, "rm -f /tmp/#{dest}")
    bolt_command = "bolt file upload #{local_user_homedir}/#{source} /tmp/#{dest}"
    flags = { '--targets' => 'localhost', '--run-as' => "'#{local_user}'" }
    result = bolt_command_on(bolt, bolt_command, flags)

    message = "Unexpected output from the command:\n#{result.cmd}"
    assert_match(/Uploaded.*#{source}.*to.*#{dest}/, result.stdout, message)

    command = "cat /tmp/local_file.txt"
    on(bolt, command, accept_all_exit_codes: true) do |res|
      assert_equal(res.exit_code, 0, 'cat was not successful')

      file_contents_message = 'The expected file contents where not observed'
      regex = /When in the course of human events/
      assert_match(regex, res.stdout, file_contents_message)
    end

    command = "ls -la /tmp/local_file.txt"
    on(bolt, command, accept_all_exit_codes: true) do |res|
      assert_equal(res.exit_code, 0, 'ls was not successful')

      file_contents_message = "File not owned by #{local_user}"
      regex = /#{local_user}/
      assert_match(regex, res.stdout, file_contents_message)
    end
  end
end
