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
    install_from_build_data_url('bolt', sha_yaml_url, bolt)
  end
end
