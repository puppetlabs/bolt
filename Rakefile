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

desc "Run RSpec tests for TravisCI that don't require WinRM or orchestrator"
RSpec::Core::RakeTask.new(:travisci) do |t|
  t.rspec_opts = '--tag ~winrm'
end

RuboCop::RakeTask.new(:rubocop) do |t|
  t.options = ['--display-cop-names', '--display-style-guide']
end

desc "Run tests and style checker"
task test: %w[spec rubocop]

desc 'Check for unapproved licenses in dependencies'
task(:license_finder) do
  system('license_finder --decisions-file=.dependency_decisions.yml') || raise(StandardError, 'Unapproved license(s) found on dependencies')
end

task :default do
  system "rake --tasks"
end

namespace :integration do
  desc 'Run tests that require a host System Under Test configured with WinRM'
  RSpec::Core::RakeTask.new(:winrm) do |t|
    t.rspec_opts = '--tag winrm'
  end

  desc 'Run tests that require a host System Under Test configured with SSH'
  RSpec::Core::RakeTask.new(:ssh) do |t|
    t.rspec_opts = '--tag ssh'
  end

  task ssh: :update_submodules
  task winrm: :update_submodules

  task :update_submodules do
    sh 'git submodule update --init'
  end
end
