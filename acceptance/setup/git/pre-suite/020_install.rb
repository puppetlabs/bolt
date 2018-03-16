# frozen_string_literal: true

test_name "Install Bolt via git" do
  sha = ''
  version = ''
  step "Clone repo" do
    on(bolt, "git clone #{ENV['GIT_SERVER']}/#{ENV['GIT_FORK']} bolt")
    if ENV['GIT_SHA'].empty?
      on(bolt, "cd bolt && git checkout #{ENV['GIT_BRANCH']}")
    else
      on(bolt, "cd bolt && git checkout #{ENV['GIT_SHA']}")
    end
  end
  step "Update submodules" do
    on(bolt, "cd bolt && git submodule update --init --recursive")
  end
  step "Construct version based on SHA" do
    sha = if ENV['GIT_SHA'].empty?
            on(bolt, 'cd bolt && git rev-parse --short HEAD').stdout.chomp
          else
            ENV['GIT_SHA']
          end
    version = "9.9.#{sha}"
    create_remote_file(bolt, 'bolt/lib/bolt/version.rb', <<-VERS)
    module Bolt
      VERSION = '#{version}'.freeze
    end
    VERS
  end
  step "Build gem" do
    case bolt['platform']
    when /windows/
      execute_powershell_script_on(bolt, 'cd bolt; gem build bolt.gemspec')
    else
      on(bolt, "cd bolt && gem build bolt.gemspec")
    end
  end
  step "Install custom gem" do
    case bolt['platform']
    when /windows/
      execute_powershell_script_on(bolt,
                                   "cd bolt; gem install bolt-#{version}.gem")
    else
      on(bolt, "cd bolt && gem install bolt-#{version}.gem")
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
