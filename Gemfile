source ENV['GEM_SOURCE'] || 'https://rubygems.org'

gemspec

group(:test) do
  gem "rubocop", require: false
end

if File.exist? "Gemfile.local"
  eval_gemfile "Gemfile.local"
end
