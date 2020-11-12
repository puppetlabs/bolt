# frozen_string_literal: true

test_name "Install Git" do
  step "Ensure Git is installed on Bolt controller" do
    result = nil
    case bolt['platform']
    when /windows/
      # use chocolatey to install latest ruby
      on(bolt, powershell('choco install git -y'))
      result = on(bolt, powershell('git --version'))
    when /debian|ubuntu|el-|centos|fedora/
      # install system ruby packages
      install_package(bolt, 'git')
      result = on(bolt, 'git --version')
    when /osx/
      # git should be already installed ?
      result = on(bolt, 'git --version')
    else
      fail_test("#{bolt['platform']} not currently a supported bolt controller")
    end
    assert_match(/git version/, result.stdout)
  end
end
