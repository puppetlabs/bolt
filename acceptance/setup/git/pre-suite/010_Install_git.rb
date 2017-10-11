test_name "Install Git" do

  step "Ensure Git is installed on Bolt controller" do
    result = nil
    case bolt['platform']
    when /windows/
      # use chocolatey to install latest ruby
      execute_powershell_script_on(bolt,"Set-ExecutionPolicy AllSigned; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))")
      on(bolt, powershell('choco install git -y'))
      # hack to add ruby path to cygwin
      #bolt.add_env_var('PATH', '/cygdrive/c/tools/ruby24/bin:PATH')
      result = on(bolt, powershell('git --version'))
    when /debian|ubuntu/
      # install system ruby packages
      install_package(bolt, 'git')
      result = on(bolt, 'git --version')
    when /el-|centos|fedora/
      # install system ruby packages
      install_package(bolt, 'git')
      result = on(bolt, 'git --version')
    when /osx/
      # git should be already installed ?
      result = on(bolt, 'git --version')
    else
      fail_test("Platform #{bolt['platform']} is not supported as a bolt controller at this time")
    end
    assert_match(/git version/, result.stdout)
  end

end
