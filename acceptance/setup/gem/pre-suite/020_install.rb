# frozen_string_literal: true

require 'bolt_setup_helper'

test_name "Install Bolt gem" do
  extend Acceptance::BoltSetupHelper

  step "Install Bolt gem" do
    install_command = "gem install bolt --source #{gem_source} --no-ri --no-rdoc"
    install_command += " -v '#{gem_version}'" unless gem_version.empty?
    case bolt['platform']
    when /windows/
      execute_powershell_script_on(bolt, install_command)
    else
      on(bolt, install_command)
    end
  end

  step "Ensure install succeeded" do
    cmd = 'bolt --help'
    case bolt['platform']
    when /windows/
      result = on(bolt, powershell(cmd))
    when /osx/
      env = 'source /etc/profile  ~/.bash_profile ~/.bash_login ~/.profile && '
      result = on(bolt, env + cmd)
    else
      result = on(bolt, cmd)
    end
    assert_match(/Usage: bolt <subcommand>/, result.stdout)
  end
end
