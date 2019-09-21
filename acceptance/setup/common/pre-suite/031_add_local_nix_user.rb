# frozen_string_literal: true

require 'bolt_setup_helper'

test_name "Configure a bolt users on *nix" do
  extend Beaker::HostPrebuiltSteps
  extend Acceptance::BoltSetupHelper

  skip_test('No local user needed for windows') if bolt['platform'] =~ /windows/
  step "Create a non-root user to test local transport run-as" do
    # Use Bolt's puppet for package testing
    result = on(bolt, 'stat /usr/local/bin/puppet', acceptable_exit_codes: [0, 1])
    puppet_path = result.exit_code == 0 ? '/usr/local/bin/puppet' : '/opt/puppetlabs/bolt/bin/puppet'

    case bolt['platform']
    when /osx/
      dir = bolt.tmpdir('osx_manifest')
      # Use beaker to set osx user and ensure they have a homedir
      bolt.user_present(local_user)
      # The puppet user resource parameter 'managehome' is not supported for macOS.
      # Note the logic to conditionally invoke createhomedir was most cleanly/reliably expressed
      # in puppet code (also tried shell script and multiple remote commands)
      create_remote_file(bolt, "#{dir}/osx_user.pp", <<~MANIFEST)
      exec { "/usr/sbin/createhomedir -c -l -u #{local_user}":
        unless => "/bin/test -d /Users/#{local_user}/Library",
      }
      MANIFEST

      on(bolt, "#{puppet_path} apply #{dir}/osx_user.pp")
    else
      on(bolt, "#{puppet_path} resource user #{local_user} ensure=present managehome=true")
    end
  end

  step "Disable requiretty for root user on el7" do
    case bolt['platform']
    when /el-7/
      create_remote_file(bolt, "/etc/sudoers.d/root", <<~FILE)
        Defaults:root !requiretty
      FILE
    end
  end
end
