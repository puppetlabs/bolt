# frozen_string_literal: true

require 'puppet_pal'

# Ensure tasks are enabled when rspec-puppet sets up an environment
# so we get task loaders.
Puppet[:tasks] = true
RSpec.configure do |c|
  c.mock_with :mocha
end
require 'puppetlabs_spec_helper/module_spec_helper'
