# frozen_string_literal: true

# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration

require 'bolt'
require 'bolt/logger'
require 'logging'
require 'net/ssh'
require 'rspec/logging_helper'
# Make sure puppet is required for the 'reset puppet settings' context
require 'puppet_pal'
# HACK: must be loaded prior to spec libs that implement stub to prevent
# RubySMB::Dcerpc::Request from shadowing 'stub' through BinData::DSLMixin::DSLFieldValidator
require 'ruby_smb'

ENV['RACK_ENV'] = 'test'
$LOAD_PATH.unshift File.join(__dir__, 'lib')

# Disables internationalized strings, which shouldn't be needed for tests.
# This gets around an issue where Puppet::Environment and GettextSetup in
# r10k are fighting over the same text domain within the FastGettext domain.
# https://github.com/voxpupuli/ra10ke/issues/39
Puppet[:disable_i18n] = true

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
    expectations.max_formatted_output_length = 500
  end

  config.filter_run_excluding windows_agents: true unless ENV['WINDOWS_AGENTS']
  config.filter_run_excluding windows: true unless ENV['BOLT_WINDOWS']
  config.filter_run_excluding sudo: true unless ENV['BOLT_SUDO_USER']

  # rspec-mocks config
  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object.
    mocks.verify_partial_doubles = true
  end

  config.before :each do
    # Disable analytics while running tests
    ENV['BOLT_DISABLE_ANALYTICS'] = 'true'

    # Ignore local bolt-project.yaml files
    allow(Bolt::Project).to receive(:create_project)
      .and_call_original
    allow(Bolt::Project).to receive(:create_project)
      .with('.')
      .and_return(Bolt::Project.create_project(Dir.mktmpdir))

    # Ignore user's known hosts and ssh config files
    conf = { user_known_hosts_file: '/dev/null/', global_known_hosts_file: '/dev/null' }
    allow(Net::SSH::Config).to receive(:for).and_return(conf)
  end

  # Reset logger after every test.
  config.after :each do
    Bolt::Logger.stream    = nil
    Bolt::Logger.analytics = nil
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
