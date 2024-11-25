# frozen_string_literal: true

test_name "Install Ruby" do
  step "Ensure Ruby is installed on Bolt controller" do
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
      on(bolt, powershell('choco list ruby')) do |output|
        version = /ruby ([2-3]\.[0-9])/.match(output.stdout)[1].delete('.')
        bolt.add_env_var('PATH', "/cygdrive/c/tools/ruby#{version}/bin:PATH")
      end
      # The ruby devkit (required to build gems with C extensions) has changed,
      # and we now need to install msys2 ourselves. https://community.chocolatey.org/packages/msys2
      on(bolt, powershell('choco install msys2 -y --params "/NoUpdate"'))
      on(bolt, powershell('ridk install 2 3'))
      # Add the msys bins to PATH
      bolt.add_env_var('PATH', "/cygdrive/c/tools/msys64:PATH")
    when /debian|ubuntu/
      # TODO: allow for tests to work or ruby3 on ubuntu
      # install system ruby packages
      install_package(bolt, 'ruby')
      install_package(bolt, 'ruby-dev')
      install_package(bolt, 'ruby-ffi')
    when /el-|centos/
      # install system ruby packages
      install_package(bolt, 'ruby')
      install_package(bolt, 'ruby-devel')
      on(bolt, 'gem install ffi')
    when /fedora/
      # install system ruby packages
      install_package(bolt, 'git')
      install_package(bolt, 'ruby')
      install_package(bolt, 'ruby-devel')
      install_package(bolt, 'libffi')
      install_package(bolt, 'libffi-devel')
      install_package(bolt, 'redhat-rpm-config')
      on(bolt, "dnf group install -y 'C Development Tools and Libraries'")
      install_package(bolt, 'rubygem-json')
      install_package(bolt, 'rubygem-bigdecimal')
      install_package(bolt, 'rubygem-io-console')
    when /osx/
      # TODO: allow for tests to work on ruby3 on macOS
    else
      fail_test("#{bolt['platform']} not currently a supported bolt controller")
    end
  end
end
