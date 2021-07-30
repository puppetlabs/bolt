#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require 'json'

params = JSON.parse($stdin.read)

if params['fail']
  exit 1
else
  output = { 'installed' => 'agent' }
  puts output.to_json
end
