# frozen_string_literal: true

require 'bolt_command_helper'

test_name "Install modules" do
  extend Acceptance::BoltCommandHelper

  on(bolt, "mkdir -p #{default_boltdir}")
  create_remote_file(bolt, "#{default_boltdir}/Puppetfile", <<-PUPPETFILE)
mod 'puppetlabs-facts', '0.2.0'
mod 'puppetlabs-service', '0.3.1'
mod 'puppet_agent',
    git: 'https://github.com/puppetlabs/puppetlabs-puppet_agent',
    ref: '319ce44a65e73bcf2712ad17be01f9636f0673c9'
PUPPETFILE

  bolt_command_on(bolt, 'bolt puppetfile install')
end
