require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

desc "Run all RSpec tests"
RSpec::Core::RakeTask.new(:spec)

desc "Run RSpec tests that don't require VM fixtures"
RSpec::Core::RakeTask.new(:unit) do |t|
  t.rspec_opts = '--tag ~ssh --tag ~winrm'
end

desc "Run RSpec tests that don't require VM fixtures or orchestrator"
RSpec::Core::RakeTask.new(:windows) do |t|
  t.rspec_opts = '--tag ~ssh --tag ~winrm --tag ~orchestrator'
end

desc "Run RSpec tests for AppVeyor that don't require SSH or orchestrator"
RSpec::Core::RakeTask.new(:appveyor) do |t|
  t.rspec_opts = '--tag ~ssh --tag ~orchestrator'
end

RuboCop::RakeTask.new(:rubocop) do |t|
  t.options = ['--display-cop-names', '--display-style-guide']
end

desc "Run tests and style checker"
task test: %w[spec rubocop]

task :default do
  system "rake --tasks"
end
