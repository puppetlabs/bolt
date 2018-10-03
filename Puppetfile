# frozen_string_literal: true

forge "http://forge.puppetlabs.com"

moduledir File.join(File.dirname(__FILE__), 'modules')

mod 'puppetlabs-package', '0.3.0'
mod 'puppetlabs-service', '0.4.0'
mod 'puppetlabs-puppet_conf', '0.3.0'
mod 'puppetlabs-facts', '0.3.1'
mod 'puppet_agent',
    git: 'https://github.com/puppetlabs/puppetlabs-puppet_agent',
    ref: '319ce44a65e73bcf2712ad17be01f9636f0673c9'

# Core types and providers for Puppet 6
mod 'puppetlabs-augeas_core', '1.0.2'
mod 'puppetlabs-host_core', '1.0.1'
mod 'puppetlabs-scheduled_task', '1.0.0'
mod 'puppetlabs-sshkeys_core', '1.0.1'
mod 'puppetlabs-zfs_core', '1.0.1'
mod 'puppetlabs-cron_core', '1.0.0'
mod 'puppetlabs-mount_core', '1.0.2'
mod 'puppetlabs-selinux_core', '1.0.1'
mod 'puppetlabs-yumrepo_core', '1.0.1'
mod 'puppetlabs-zone_core', '1.0.1'

# If we don't list these modules explicitly, r10k will purge them
mod 'canary', local: true
mod 'aggregate', local: true
mod 'puppetdb_fact', local: true
