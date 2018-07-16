# frozen_string_literal: true

require 'bolt_command_helper'

test_name "Install puppetlabs-facts" do
  extend Acceptance::BoltCommandHelper
  on(bolt, puppet('module', 'install', 'puppetlabs-facts', '--target-dir', default_modulepath))
end
