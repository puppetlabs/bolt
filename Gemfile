source ENV['GEM_SOURCE'] || 'https://rubygems.org'

gemspec

if File.exist? "Gemfile.local"
  eval_gemfile "Gemfile.local"
end
