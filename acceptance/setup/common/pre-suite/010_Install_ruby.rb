test_name "Setup environment" do

  step "Ensure Ruby is installed on Bolt controller" do
    result = nil
    case bolt['platform']
    when /windows/
      # use chocolatey to install latest ruby
      execute_powershell_script_on(bolt,"Set-ExecutionPolicy AllSigned; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))")
      # hack to add chocolatey path to cygwin: this path should at least be
      # instrospected from the STDOUT of the installer.
      bolt.add_env_var('PATH', '/cygdrive/c/ProgramData/chocolatey/bin:PATH')
      on(bolt, powershell('choco install ruby -y'))
      # hack to add ruby path to cygwin
      bolt.add_env_var('PATH', '/cygdrive/c/tools/ruby24/bin:PATH')
      result = on(bolt, powershell('ruby --version'))
    when /debian|ubuntu/
      # install system ruby packages
      install_package(bolt, 'ruby')
      install_package(bolt, 'ruby-dev')
      result = on(bolt, 'ruby --version')
    when /el-|centos|fedora/
      # install system ruby packages
      install_package(bolt, 'ruby')
      install_package(bolt, 'ruby-devel')
      result = on(bolt, 'ruby --version')
    when /osx/
      # ruby dev tools should be already installed
      result = on(bolt, 'ruby --version')
    else
      fail_test("Platform #{bolt['platform']} is not supported as a bolt controller at this time")
    end
    assert_match(/ruby 2/, result.stdout)
  end

end
