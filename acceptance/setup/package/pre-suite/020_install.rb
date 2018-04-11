# frozen_string_literal: true

# Inspired by https://github.com/puppetlabs/pdk/blob/master/package-testing/pre/000_install_package.rb
# Uses helpers from beaker-puppet to fetch build defaults

test_name 'Install Bolt package' do
  if ENV['LOCAL_PKG']
    pkg = File.basename(ENV['LOCAL_PKG'])
    step "Install local package #{pkg}" do
      scp_to(bolt, ENV['LOCAL_PKG'], pkg)
      # TODO: add Windows::Pkg::install_local_package
      if bolt['platform'] =~ /windows/
        generic_install_msi_on(bolt, pkg)
      else
        bolt.install_local_package(pkg)
      end
    end
  else
    dev_builds_url = ENV['DEV_BUILDS_URL'] || 'http://builds.delivery.puppetlabs.net'
    sha_yaml_url = "#{dev_builds_url}/bolt/#{ENV['SHA']}/artifacts/#{ENV['SHA']}.yaml"
    unless link_exists?(sha_yaml_url)
      fail_test("<SHA>.yaml URL '#{sha_yaml_url}' does not exist.")
    end

    base_url, build_details = fetch_build_details(sha_yaml_url)
    artifact_url, _ = host_urls(bolt, build_details, base_url)

    case bolt['platform']
      # TODO: BKR-1109 requests a supported way to install packages on Windows and OSX
    when %r{windows}
      generic_install_msi_on(bolt, artifact_url)
    when %r{osx}
      on bolt, "curl -O #{artifact_url}"
      bolt.install_package('bolt*')
    else
      bolt.install_package(artifact_url)
    end
  end
end
