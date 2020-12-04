# frozen_string_literal: true

require 'json'

a = { "value" => ENV['BOLT_TEST_PLUGIN_VALUE'] }.to_json
puts a
