# frozen_string_literal: true

# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration

require 'bolt'
require 'bolt/logger'
require 'logging'
require 'rspec/logging_helper'
# Make sure puppet is required for the 'reset puppet settings' context
require_relative '../vendored/require_vendored'

$LOAD_PATH.unshift File.join(__dir__, 'lib')

# Ensure tasks are enabled when rspec-puppet sets up an environment
# so we get task loaders.
Puppet[:tasks] = true
require 'puppetlabs_spec_helper/module_spec_helper'

RSpec.shared_context 'reset puppet settings' do
  after :each do
    # reset puppet settings so that they can be initialized again
    Puppet.settings.instance_exec do
      clear_everything_for_tests
    end
  end
end

RSpec.configure do |config|
  Bolt::Logger.initialize_logging
  include RSpec::LoggingHelper
  config.capture_log_messages

  # rspec-expectations config
  config.expect_with :rspec do |expectations|
    #     be_bigger_than(2).and_smaller_than(4).description
    #     # => "be bigger than 2 and smaller than 4"
    # ...rather than:
    #     # => "be bigger than 2"
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # rspec-mocks config
  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object.
    mocks.verify_partial_doubles = true
  end

  # This will be default in future rspec, leave it on
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Allows RSpec to persist some state between runs in order to support
  # the `--only-failures` and `--next-failure` CLI options.
  config.example_status_persistence_file_path = "spec/examples.txt"

  # config.warnings = true

  # Make it possible to include the 'reset puppet settings' shared context
  # in a group (or even an individual test) by specifying
  # `:reset_puppet_settings' metadata on the group/test
  config.include_context 'reset puppet settings', :reset_puppet_settings
end
