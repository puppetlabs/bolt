# frozen_string_literal: true

require 'bolt_command_helper'

test_name "Install modules" do
  extend Acceptance::BoltCommandHelper

  on(bolt, "mkdir -p #{default_boltdir}")
  bolt_command_on(bolt, "cp bolt/Puppetfile #{default_boltdir}")
  bolt_command_on(bolt, "cd #{default_boltdir} && r10k puppetfile install Puppetfile")
end
