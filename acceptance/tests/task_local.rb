# frozen_string_literal: true

require 'bolt_command_helper'

test_name "bolt task run should execute tasks on localhost via local transport" do
  extend Acceptance::BoltCommandHelper
  extend Acceptance::BoltSetupHelper
  dir = bolt.tmpdir('local_task')

  if bolt['platform'] =~ /windows/
    step "create task on bolt controller" do
      on(bolt, "mkdir -p #{dir}/modules/test/tasks")
      create_remote_file(bolt, "#{dir}/modules/test/tasks/test_profile.ps1", <<-FILE)
      Write-Host 'Dont Load Profile'
      FILE
    end

    step "execute `bolt task run` via local transport and ensure profile not loaded" do
      bolt_command = "bolt task run test::test_profile"

      flags = {
        '--targets' => 'localhost',
        '--modulepath' => "#{dir}/modules"
      }

      inspect_profile_tracker = "\"if (Test-Path -Path #{profile_tracker.inspect}) " \
                                "{ Get-Content -Path #{profile_tracker.inspect} }\""
      profile_pre = on(bolt, powershell(inspect_profile_tracker))
      result = bolt_command_on(bolt, bolt_command, flags)
      assert_match(/Dont Load Profile/, result.stdout, 'failed to run powershell task')
      profile_post = on(bolt, powershell(inspect_profile_tracker))
      assert_equal(profile_pre.stdout, profile_post.stdout, 'Profile was loaded')
    end
  else
    step "create task on bolt controller" do
      on(bolt, "mkdir -p #{dir}/modules/test/tasks")
      create_remote_file(bolt, "#{dir}/modules/test/tasks/whoami_nix", <<-FILE)
      #!/bin/sh
      echo "$PT_greetings from $(whoami)"
      FILE
    end

    step "execute `bolt task run` on localhost via local transport" do
      bolt_command = "bolt task run test::whoami_nix greetings=hello"
      flags = {
        '--targets' => 'localhost',
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
        '--targets' => 'localhost',
        '--modulepath' => "#{local_user_homedir}/modules",
        '--run-as' => "'#{local_user}'"
      }

      result = bolt_command_on(bolt, bolt_command, flags)
      message = "Unexpected output from the command:\n#{result.cmd}"
      regex = /hello from #{local_user}/
      assert_match(regex, result.stdout, message)
    end
  end
end
