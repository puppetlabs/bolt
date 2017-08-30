source ENV['GEM_SOURCE'] || 'https://rubygems.org'

gemspec

gem "puppet", git: 'https://github.com/puppetlabs/puppet.git'
gem "rubocop", require: false

if File.exist? "Gemfile.local"
  eval_gemfile "Gemfile.local"
end
