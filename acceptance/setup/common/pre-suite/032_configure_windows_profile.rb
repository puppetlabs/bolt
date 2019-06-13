# frozen_string_literal: true

require 'bolt_setup_helper'

test_name "Configure Windows Profile" do
  extend Acceptance::BoltSetupHelper

  step "Configure a Windows Profile that contains will write to a file every time it is loaded" do
    if bolt['platform'] =~ /windows/
      execute_powershell_script_on(bolt, <<-PS)
$profileTracker = #{profile_tracker.inspect}
$BaseDir = Split-Path $profileTracker
if (!(Test-Path -Path $BaseDir ))
{ New-Item -Type Directory -Path $BaseDir -Force }
if (!(Test-Path -Path $PROFILE.AllUsersAllHosts))
{ New-Item -Type File -Path $PROFILE.AllUsersAllHosts -Force }
$ProfileCode = [string]::Format('"Profile Loaded" | Out-File {0} -Append', $profileTracker)
Set-Content -Path $PROFILE.AllUsersAllHosts -value $ProfileCode
PS

      result = execute_powershell_script_on(bolt, <<-PS)
Type $PROFILE.AllUsersAllHosts
PS
      assert_match(result.stdout.strip, "\"Profile Loaded\" | Out-File #{profile_tracker} -Append")
    end
  end
end
