# frozen_string_literal: true

step 'Install puppet-agent package' do
  case bolt.platform
  when /((?:sles|el)-\d+)/
    platform = Regexp.last_match(1)
    bolt.install_package_with_rpm("http://yum.puppetlabs.com/puppet5/puppet5-release-#{platform}.noarch.rpm")
  when /ubuntu|deb/
    codename = Platform.new(bolt.platform).codename
    release_package = "puppet5-release-#{codename}.deb"
    on bolt, "curl -L http://apt.puppetlabs.com/#{release_package} -O"
    bolt.install_local_package(release_package)
  else
    fail_test "Can't install puppet-agent on #{host.platform}"
  end
end
