# frozen_string_literal: true

test_name "Install Ruby" do
  step "Ensure Ruby is installed on Bolt controller" do
    result = nil
    case bolt['platform']
    when /windows/
      # use chocolatey to install latest ruby
      execute_powershell_script_on(bolt, <<-PS)
Set-ExecutionPolicy AllSigned
$choco_install_uri = 'https://chocolatey.org/install.ps1'
iex ((New-Object System.Net.WebClient).DownloadString($choco_install_uri))
PS
      # HACK: to add chocolatey path to cygwin: this path should at least be
      # instrospected from the STDOUT of the installer.
      bolt.add_env_var('PATH', '/cygdrive/c/ProgramData/chocolatey/bin:PATH')
      on(bolt, powershell('choco install ruby -y'))
      # HACK: to add ruby path to cygwin
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
      fail_test("#{bolt['platform']} not currently a supported bolt controller")
    end
    assert_match(/ruby 2/, result.stdout)
  end
end
