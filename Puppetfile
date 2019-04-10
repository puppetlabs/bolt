# frozen_string_literal: true

forge "http://forge.puppetlabs.com"

moduledir File.join(File.dirname(__FILE__), 'modules')

# Core modules used by 'apply'
mod 'puppetlabs-service', '0.6.0'
mod 'puppetlabs-facts', '0.5.0'
mod 'puppet_agent',
    git: 'https://github.com/puppetlabs/puppetlabs-puppet_agent',
    ref: '8b56966233536a4829d1ff533b720fe1bc1145b8'

# Core types and providers for Puppet 6
mod 'puppetlabs-augeas_core', '1.0.3'
mod 'puppetlabs-host_core', '1.0.1'
mod 'puppetlabs-scheduled_task', '1.0.0'
mod 'puppetlabs-sshkeys_core', '1.0.1'
mod 'puppetlabs-zfs_core', '1.0.1'
mod 'puppetlabs-cron_core', '1.0.0'
mod 'puppetlabs-mount_core', '1.0.2'
mod 'puppetlabs-selinux_core', '1.0.1'
mod 'puppetlabs-yumrepo_core', '1.0.1'
mod 'puppetlabs-zone_core', '1.0.1'

# Useful additional modules
mod 'puppetlabs-package', '0.5.0'
mod 'puppetlabs-puppet_conf', '0.3.0'
mod 'puppetlabs-python_task_helper', '0.2.0'
mod 'puppetlabs-reboot', '2.1.2'
mod 'puppetlabs-ruby_task_helper', '0.3.0'

# If we don't list these modules explicitly, r10k will purge them
mod 'canary', local: true
mod 'aggregate', local: true
mod 'puppetdb_fact', local: true
