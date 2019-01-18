# frozen_string_literal: true

require 'bolt_command_helper'

test_name "Install modules" do
  extend Acceptance::BoltCommandHelper

  on(bolt, "mkdir -p #{default_boltdir}")
  create_remote_file(bolt, "#{default_boltdir}/Puppetfile", <<-PUPPETFILE)
mod 'puppetlabs-facts', '0.5.0'
mod 'puppetlabs-service', '0.5.0'
mod 'puppetlabs-puppet_agent', '2.0.1'
PUPPETFILE

  bolt_command_on(bolt, 'bolt puppetfile install')
end
