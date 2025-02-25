#!/usr/bin/env ruby
# frozen_string_literal: true

# effectively the same as bolt/exe/bolt, but with gem output

require 'bolt'
require 'bolt/cli'

def suppress_outputs
  null_io = !!File::ALT_SEPARATOR ? File::NULL : FILE::SEPARATOR
  out = $stdout.clone
  err = $stderr.clone
  $stderr.reopen(null_io, 'w')
  $stdout.reopen(null_io, 'w')
  yield
ensure
  $stdout.reopen(out)
  $stderr.reopen(err)
end

cli = Bolt::CLI.new(['--help'])
begin
  # hide Bolt output produced by executing cli
  suppress_outputs { cli.execute(cli.parse) }
# eat the CLIExit exception
rescue Bolt::CLIExit
  nil
ensure
  # emit loaded code files, typically .rb and .so
  puts $LOADED_FEATURES.sort
end
