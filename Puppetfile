# frozen_string_literal: true

forge "http://forge.puppetlabs.com"

moduledir File.join(File.dirname(__FILE__), 'modules')

mod 'puppetlabs-package', '0.2.0'
mod 'puppetlabs-service', '0.3.1'
mod 'puppetlabs-puppet_conf', '0.2.0'
mod 'puppetlabs-facts', '0.2.0'
mod 'puppet_agent',
    git: 'https://github.com/puppetlabs/puppetlabs-puppet_agent',
    ref: '319ce44a65e73bcf2712ad17be01f9636f0673c9'

# If we don't list these modules explicitly, r10k will purge them
mod 'canary', local: true
mod 'aggregate', local: true
mod 'puppetdb_fact', local: true
