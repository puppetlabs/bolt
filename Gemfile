source ENV['GEM_SOURCE'] || 'https://rubygems.org'

gemspec

gem "rubocop", require: false

gem 'orchestrator_client', git: 'git@github.com:puppetlabs/orchestrator_api-ruby.git', branch: 'master'

if File.exist? "Gemfile.local"
  eval_gemfile "Gemfile.local"
end
