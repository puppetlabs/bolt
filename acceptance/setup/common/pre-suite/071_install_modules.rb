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
    ref: 'e38bc2113f22f475a245bfa3b453b24b1ef2b063'
PUPPETFILE

  bolt_command_on(bolt, 'bolt puppetfile install')
end
