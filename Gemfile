source ENV['GEM_SOURCE'] || 'https://rubygems.org'

gemspec

group(:test) do
  gem "beaker-hostgenerator"
  gem "rubocop", '0.50.0', require: false
  gem 'license_finder', '~> 3.0.4'
end

if File.exist? "Gemfile.local"
  eval_gemfile "Gemfile.local"
end
