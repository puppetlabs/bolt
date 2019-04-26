# frozen_string_literal: true

require 'bolt_command_helper'

test_name "bolt task run should execute tasks on localhost via local transport" do
  extend Acceptance::BoltCommandHelper
  extend Acceptance::BoltSetupHelper

  skip_test('no applicable nodes to test on') if bolt['platform'] =~ /windows/

  dir = bolt.tmpdir('local_task')

  step "create task on bolt controller" do
    on(bolt, "mkdir -p #{dir}/modules/test/tasks")
    create_remote_file(bolt, "#{dir}/modules/test/tasks/whoami_nix", <<-FILE)
    #!/bin/sh
    echo "$PT_greetings from $(whoami)"
    FILE
    # TODO: Use input_method: both (default) once bug BOLT-1283 is fixed
    conf = { 'input_method' => 'environment' }
    create_remote_file(bolt, "#{dir}/modules/test/tasks/whoami_nix.json", conf.to_json)
  end

  step "execute `bolt task run` on localhost via local transport" do
    bolt_command = "bolt task run test::whoami_nix greetings=hello"
    flags = {
      '--nodes' => 'localhost',
      '--modulepath' => "#{dir}/modules"
    }

    result = bolt_command_on(bolt, bolt_command, flags)
    message = "Unexpected output from the command:\n#{result.cmd}"
    regex = /hello from root/
    assert_match(regex, result.stdout, message)
  end

  step "execute `bolt task run` on localhost via local transport with run-as" do
    on(bolt, "cp -r #{dir}/modules #{local_user_homedir}")
    on(bolt, "chown -R #{local_user} #{local_user_homedir}/modules")

    bolt_command = "bolt task run test::whoami_nix greetings=hello"
    flags = {
      '--nodes' => 'localhost',
      '--modulepath' => "#{local_user_homedir}/modules",
      '--run-as' => "'#{local_user}'"
    }

    result = bolt_command_on(bolt, bolt_command, flags)
    message = "Unexpected output from the command:\n#{result.cmd}"
    regex = /hello from #{local_user}/
    assert_match(regex, result.stdout, message)
  end
end
