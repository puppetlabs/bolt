# frozen_string_literal: true

require_relative '../../../vendored/require_vendored.rb'

# Add bolt spec helpers
bolt_dir = Gem::Specification.find_by_name('bolt').gem_dir
$LOAD_PATH.unshift(File.join(bolt_dir, 'spec', 'lib'))

# Ensure tasks are enabled when rspec-puppet sets up an environment
# so we get task loaders.
Puppet[:tasks] = true
require 'puppetlabs_spec_helper/module_spec_helper'
