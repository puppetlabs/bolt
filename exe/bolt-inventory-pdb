#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bolt_ext/puppetdb_inventory'

begin
  Bolt::PuppetDBInventory::CLI.new(ARGV).run
  exit 0
rescue StandardError => e
  warn "Error: #{e}"
  warn e.backtrace if @trace
  exit 1
end
