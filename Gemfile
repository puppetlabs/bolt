# frozen_string_literal: true

source ENV['GEM_SOURCE'] || 'https://rubygems.org'

gemspec

# Required to pick up plan specs in the rake spec task
gem "puppetlabs_spec_helper", git: 'https://github.com/puppetlabs/puppetlabs_spec_helper.git', ref: 'master'

group(:test) do
  gem "beaker-hostgenerator"
  gem "gettext-setup", '~> 0.28', require: false
  gem "rubocop", '~> 0.50', require: false
end

local_gemfile = File.join(__dir__, 'Gemfile.local')
if File.exist? local_gemfile
  eval_gemfile local_gemfile
end
