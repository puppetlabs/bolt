# frozen_string_literal: true

require 'bolt_command_helper'

test_name "bolt script run should execute script on localhost via local transport" do
  extend Acceptance::BoltCommandHelper
  extend Acceptance::BoltSetupHelper

  skip_test('no applicable nodes to test on') if bolt['platform'] =~ /windows/

  script = "test_local.sh"

  step "create script on bolt controller" do
    create_remote_file(bolt, script, <<-FILE)
    #!/bin/sh
    echo "$* there $(whoami)"
    FILE
  end

  step "execute `bolt script run` on localhost" do
    bolt_command = "bolt script run #{script} hello"

    flags = { '--nodes' => 'localhost' }

    result = bolt_command_on(bolt, bolt_command, flags)
    message = "Unexpected output from the command:\n#{result.cmd}"
    assert_match(/hello there root/, result.stdout, message)
  end

  step "execute `bolt script run` on localhost with run-as" do
    # make sure local_user is allowed to run script
    local_owned_script = "#{local_user_homedir}/test_local.sh"
    on(bolt, "cp #{script} #{local_owned_script}")
    on(bolt, "chown -R local_user #{local_owned_script}")

    bolt_command = "bolt script run #{local_owned_script} hello"

    flags = { '--nodes' => 'localhost', '--run-as' => "'#{local_user}'" }

    result = bolt_command_on(bolt, bolt_command, flags)
    message = "Unexpected output from the command:\n#{result.cmd}"
    assert_match(/hello there #{local_user}/, result.stdout, message)
  end
end
