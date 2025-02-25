#!/foo/ruby
# frozen_string_literal: true

require 'json'

result = { 'env' => ENV.fetch('PT_message', nil), 'stdin' => JSON.parse(gets)['message'] }
puts result.to_json
