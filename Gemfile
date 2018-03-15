source ENV['GEM_SOURCE'] || 'https://rubygems.org'

gemspec

group(:test) do
  gem "beaker-hostgenerator"
  gem "gettext-setup", '~> 0.28', require: false
  gem "rubocop", '0.50.0', require: false
end

if File.exist? "Gemfile.local"
  eval_gemfile "Gemfile.local"
end
