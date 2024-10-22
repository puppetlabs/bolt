# frozen_string_literal: true

source ENV['GEM_SOURCE'] || 'https://rubygems.org'

# Disable analytics when running in development
ENV['BOLT_DISABLE_ANALYTICS'] = 'true'

# Disable warning that Bolt may be installed as a gem
ENV['BOLT_GEM'] = 'true'

gemspec

group(:bolt_server) do
  # Bolt server gems are managed here not in the gemspec
  gem "hocon", '>= 1.2.5'
  gem "json-schema", '>= 2.8.0'
  gem "puma", '>= 3.12.0'
  gem "rack", '>= 2.0.5'
  gem "rails-auth", '>= 2.1.4'
  gem "sinatra", '>= 2.0.4'
end

# Optional paint gem for rainbow outputter
gem "paint", "~> 2.2"

group(:test) do
  gem "beaker-hostgenerator"
  gem "mocha", '~> 1.4.0'
  gem "rack-test", '~> 1.0'
  gem "rubocop", '~> 1.9.0', require: false
  gem "rubocop-rake", require: false
end

group(:packaging) do
  gem 'packaging', '~> 0.105'
end

local_gemfile = File.join(__dir__, 'Gemfile.local')
if File.exist? local_gemfile
  eval_gemfile local_gemfile
end
