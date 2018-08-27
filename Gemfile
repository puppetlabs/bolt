# frozen_string_literal: true

source ENV['GEM_SOURCE'] || 'https://rubygems.org'

# Disable analytics when running in development
ENV['BOLT_DISABLE_ANALYTICS'] = 'true'

gemspec
gem  "winrm-fs", git: "https://github.com/donoghuc/winrm-fs.git", branch: "BOLT-664"
gem "hocon"
gem "puma"
gem "rack"
gem "sinatra"

# Required to pick up plan specs in the rake spec task
gem "puppetlabs_spec_helper",
    git: 'https://github.com/puppetlabs/puppetlabs_spec_helper.git',
    ref: '96a633ebf1a1e88062bf726d4271a3251baf082e'

group(:test) do
  gem "beaker-hostgenerator"
  gem "gettext-setup", '~> 0.28', require: false
  gem "mocha", '~> 1.4.0'
  gem "rack-test", '~> 1.0'
  gem "rubocop", '~> 0.50', require: false
end

group(:development) do
  gem "puppet-strings", "~> 2.0"
end

local_gemfile = File.join(__dir__, 'Gemfile.local')
if File.exist? local_gemfile
  eval_gemfile local_gemfile
end
