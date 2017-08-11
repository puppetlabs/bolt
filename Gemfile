source ENV['GEM_SOURCE'] || 'https://rubygems.org'

gemspec

if File.exists? "Gemfile.local"
  eval_gemfile "Gemfile.local"
end
