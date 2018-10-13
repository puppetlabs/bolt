#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require 'json'

def hi_from_ruby
  { "ruby" => "Hi" }
end

puts hi_from_ruby.to_json
