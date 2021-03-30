# frozen_string_literal: true

RSpec.configure do |c|
  c.mock_with :mocha
end
$LOAD_PATH.unshift File.join(__dir__, '..', '..', 'lib')
require 'puppetlabs_spec_helper/module_spec_helper'
