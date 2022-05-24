# frozen_string_literal: true

require 'bolt_command_helper'
require 'bolt_setup_helper'

test_name "bolt command run should execute command on localhost via local transport" do
  extend Acceptance::BoltCommandHelper
  extend Acceptance::BoltSetupHelper

  skip_test('no applicable nodes to test on') if bolt['platform'] =~ /windows/

  step "execute `bolt command run` via local transport" do
    command = 'echo """hello from $(hostname)"""'
    bolt_command = "bolt command run '#{command}'"
    flags = { '--targets' => 'localhost' }

    result = bolt_command_on(bolt, bolt_command, flags)

    message = "Unexpected output from the command:\n#{result.cmd}"
    regex = /hello from #{bolt.hostname.split('.')[0]}/
    assert_match(regex, result.stdout, message)
  end

  step "execute `bolt command run` via local transport using run-as" do
    command = 'whoami'
    bolt_command = "bolt command run '#{command}'"
    flags = { '--targets' => 'localhost', '--run-as' => "'#{local_user}'" }

    result = bolt_command_on(bolt, bolt_command, flags)

    message = "command did not execute as #{local_user}:\n#{result.cmd}"
    regex = /#{local_user}/
    assert_match(regex, result.stdout, message)
  end
end
