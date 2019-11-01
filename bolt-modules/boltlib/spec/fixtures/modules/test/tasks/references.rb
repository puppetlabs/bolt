#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'

values = {
  "value" => {
    "name" => "127.0.0.1"
  }
}

puts values.to_json
