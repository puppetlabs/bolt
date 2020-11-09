# frozen_string_literal: true

require 'json'

input = JSON.parse($stdin.read)
hash = { "_sensitive" => input }
puts hash.to_json
