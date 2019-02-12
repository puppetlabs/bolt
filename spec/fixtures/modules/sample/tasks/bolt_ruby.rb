#!/foo/ruby
# frozen_string_literal: true

require 'json'

result = { 'env' => ENV['PT_message'], 'stdin' => JSON.parse(gets)['message'] }
puts result.to_json
