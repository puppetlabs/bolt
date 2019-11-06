# frozen_string_literal: true

require 'bolt_command_helper'

test_name "bolt script run should execute script on localhost via local transport" do
  extend Acceptance::BoltCommandHelper
  extend Acceptance::BoltSetupHelper

  if bolt['platform'] =~ /windows/
    script = "test_local.ps1"

    step "create powershell script on bolt controller" do
      create_remote_file(bolt, script, <<-FILE)
      Write-Host "Dont Load Profile"
      FILE
    end

    step "execute powershell script via local transport without loading powershell profile" do
      bolt_command = "bolt script run #{script}"
      flags = { '--targets' => 'localhost' }

      inspect_profile_tracker = "\"if (Test-Path -Path #{profile_tracker.inspect}) " \
                                "{ Get-Content -Path #{profile_tracker.inspect} }\""
      profile_pre = on(bolt, powershell(inspect_profile_tracker))
      result = bolt_command_on(bolt, bolt_command, flags)
      assert_match(/Dont Load Profile/, result.stdout, 'failed to run powershell script')
      profile_post = on(bolt, powershell(inspect_profile_tracker))
      assert_equal(profile_pre.stdout, profile_post.stdout, 'Profile was loaded')
    end
  else
    script = "test_local.sh"

    step "create script on bolt controller" do
      create_remote_file(bolt, script, <<-FILE)
      #!/bin/sh
      echo "$* there $(whoami)"
      FILE
    end

    step "execute `bolt script run` on localhost" do
      bolt_command = "bolt script run #{script} hello"

      flags = { '--targets' => 'localhost' }

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

      flags = { '--targets' => 'localhost', '--run-as' => "'#{local_user}'" }

      result = bolt_command_on(bolt, bolt_command, flags)
      message = "Unexpected output from the command:\n#{result.cmd}"
      assert_match(/hello there #{local_user}/, result.stdout, message)
    end
  end
end
