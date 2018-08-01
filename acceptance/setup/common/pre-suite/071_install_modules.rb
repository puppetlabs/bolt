# frozen_string_literal: true

require 'bolt_command_helper'

test_name "Install modules" do
  extend Acceptance::BoltCommandHelper

  create_remote_file(bolt, "#{default_boltdir}/Puppetfile", <<-PUPPETFILE)
mod 'puppetlabs-facts', '0.2.0'
PUPPETFILE

  bolt_command_on(bolt, 'bolt puppetfile install')
end
