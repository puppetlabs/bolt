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
      # public_suffix for win requires Ruby version >= 2.6
      # current Ruby 2.5.0 works with public_suffix version 4.0.7
      on(bolt, powershell('gem install public_suffix -v 6.0.1'))
      # current Ruby 2.5.0 works with puppet-strings 2.9.0
      on(bolt, powershell('gem install puppet-strings -v 4.1.3'))
      # net-ssh 7.x no longer supports ruby 2.5
      on(bolt, powershell('gem install net-ssh -v 7.3.0'))
      # semantic puppet no longer supports ruby < 2.7
      on(bolt, powershell('gem install semantic_puppet -v 1.1.0'))
      on(bolt, powershell('gem install puppet -v 8.10.0'))
      on(bolt, powershell('gem install highline -v 3.1.1'))
    when /debian|ubuntu/
      # install system ruby packages
      install_package(bolt, 'ruby')
      install_package(bolt, 'ruby-ffi')
      on(bolt, 'gem install fast_gettext -v 2.4.0')
      # semantic puppet no longer supports ruby < 2.7
      on(bolt, 'gem install semantic_puppet -v 1.1.0')
      on(bolt, 'gem install puppet -v 8.10.0')
      on(bolt, 'gem install highline -v 3.1.1')
      on(bolt, 'gem install nori -v 2.7.1')
      on(bolt, 'gem install CFPropertyList -v 3.0.7')
      on(bolt, 'gem install winrm -v 2.3.9')
      on(bolt, 'gem install public_suffix -v 6.0.1')
    when /el-|centos/
      # install system ruby packages
      install_package(bolt, 'ruby')
      install_package(bolt, 'rubygem-json')
      install_package(bolt, 'rubygem-ffi')
      install_package(bolt, 'rubygem-bigdecimal')
      install_package(bolt, 'rubygem-io-console')
      on(bolt, 'gem install highline -v 3.1.1')
    when /fedora/
      # install system ruby packages
      install_package(bolt, 'ruby')
      install_package(bolt, 'ruby-devel')
      install_package(bolt, 'libffi')
      install_package(bolt, 'libffi-devel')
      install_package(bolt, 'redhat-rpm-config')
      on(bolt, "dnf group install -y 'C Development Tools and Libraries'")
      install_package(bolt, 'rubygem-json')
      install_package(bolt, 'rubygem-bigdecimal')
      install_package(bolt, 'rubygem-io-console')
      on(bolt, 'gem install highline -v 3.1.1')
    when /osx/
      # System ruby for osx is 2.3. winrm-fs and its dependencies require > 2.3.
      on(bolt, 'gem install nori -v 2.7.0 --no-document')
      on(bolt, 'gem install winrm -v 2.3.9 --no-document')
      on(bolt, 'gem install winrm-fs -v 1.3.5 --no-document')
      on(bolt, 'gem install public_suffix -v 6.0.1 --no-document')
      on(bolt, 'gem install CFPropertyList -v 3.0.7 --no-document')
      on(bolt, 'gem install fast_gettext -v 2.4.0')
      # System ruby for osx12 is 2.6, which can only manage puppet-strings 2.9.0
      on(bolt, 'gem install puppet-strings -v 4.1.3 --no-document')
      # semantic puppet no longer supports ruby < 2.7
      on(bolt, 'gem install semantic_puppet -v 1.1.0')
      on(bolt, 'gem install puppet -v 8.10.0')
      on(bolt, 'gem install highline -v 3.1.1')
    else
      fail_test("#{bolt['platform']} not currently a supported bolt controller")
    end
  end
end
