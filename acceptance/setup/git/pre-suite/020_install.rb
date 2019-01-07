# frozen_string_literal: true

require 'bolt_setup_helper'

test_name "Install Bolt via git" do
  extend Acceptance::BoltSetupHelper

  sha = ''
  version = ''
  step "Clone repo" do
    # Cleanup previous runs
    on(bolt, "rm -rf bolt")
    on(bolt, "git clone #{git_server}/#{git_fork} bolt")
    if git_sha.empty?
      on(bolt, "cd bolt && git checkout #{git_branch}")
    else
      on(bolt, "cd bolt && git checkout #{git_sha}")
    end
  end

  step "Update submodules" do
    on(bolt, "cd bolt && git submodule update --init --recursive")
  end

  step "Construct version based on SHA" do
    sha = if git_sha.empty?
            on(bolt, 'cd bolt && git rev-parse --short HEAD').stdout.chomp
          else
            git_sha
          end
    version = "9.9.#{sha}"
    create_remote_file(bolt, 'bolt/lib/bolt/version.rb', <<-VERS)
    module Bolt
      VERSION = '#{version}'.freeze
    end
    VERS
  end

  step "Build gem" do
    build_command = "cd bolt; gem build bolt.gemspec"
    case bolt['platform']
    when /windows/
      execute_powershell_script_on(bolt, build_command)
    else
      on(bolt, build_command)
    end
  end

  step "Install custom gem" do
    install_command = "cd bolt; gem install bolt-#{version}.gem --no-document"
    case bolt['platform']
    when /windows/
      execute_powershell_script_on(bolt, install_command)
    else
      on(bolt, install_command)
    end
  end

  step "Ensure install succeeded" do
    cmd = 'bolt --version'
    case bolt['platform']
    when /windows/
      result = on(bolt, powershell(cmd))
    when /osx/
      env = 'source /etc/profile  ~/.bash_profile ~/.bash_login ~/.profile && '
      result = on(bolt, env + cmd)
    else
      result = on(bolt, cmd)
    end
    assert_match(/#{version}/, result.stdout)
  end
end
