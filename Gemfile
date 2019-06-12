# frozen_string_literal: true

source ENV['GEM_SOURCE'] || 'https://rubygems.org'

# Disable analytics when running in development
ENV['BOLT_DISABLE_ANALYTICS'] = 'true'

gemspec

# Bolt server gems are managed here not in the gemspec
gem "hocon", '>= 1.2.5'
gem "json-schema", '>= 2.8.0'
gem "puma", '>= 3.12.0'
gem "rack", '>= 2.0.5'
gem "rails-auth", '>= 2.1.4'
gem "sinatra", '>= 2.0.4'

# Required to pick up plan specs in the rake spec task
# TODO: move to test group?
gem "puppetlabs_spec_helper",
    git: 'https://github.com/puppetlabs/puppetlabs_spec_helper.git',
    ref: '96a633ebf1a1e88062bf726d4271a3251baf082e'

gem "puppet-resource_api",
    git: 'https://github.com/DavidS/puppet-resource_api.git',
    ref: 'pup-9747-bolt-attribute-filtering'


group(:test) do
  gem "beaker-hostgenerator"
  gem "gettext-setup", '~> 0.28', require: false
  gem "mocha", '~> 1.4.0'
  gem "rack-test", '~> 1.0'
  gem "rubocop", '~> 0.61', require: false
end

group(:development) do
  gem "puppet-strings", "~> 2.0"
end

local_gemfile = File.join(__dir__, 'Gemfile.local')
if File.exist? local_gemfile
  eval_gemfile local_gemfile
end
