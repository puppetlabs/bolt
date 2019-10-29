# frozen_string_literal: true

require 'bolt_command_helper'

test_name "Install modules" do
  extend Acceptance::BoltCommandHelper

  # Install modules to the `modules` dir in bolt gem path to replicate
  # where modules will be with system packages.
  find_bolt_gem = bolt_command_on(bolt, "gem which bolt")
  bolt_gem_path = find_bolt_gem.stdout.strip.sub(%r{/lib/bolt.rb}, "")
  command = "cd #{bolt_gem_path}; r10k puppetfile install"
  # For osx, ensure command uses bash instead of sh
  command = "bash -c '#{command}'" if bolt.platform =~ /osx/
  bolt_command_on(bolt, command)
end
