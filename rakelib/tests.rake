# frozen_string_literal: true

# rubocop:disable Lint/SuppressedException
begin
  require 'rspec/core/rake_task'

  def generate_opts(include_tags: [], exclude_tags: [])
    opts = include_tags.map { |t| "--tag #{t}" } + exclude_tags.map { |t| "--tag ~#{t}" }
    opts.join(' ').chomp
  end

  namespace :tests do
    desc "Run all RSpec tests"
    RSpec::Core::RakeTask.new(:spec)

    desc "Run RSpec tests that do not require VM fixtures or a particular shell"
    RSpec::Core::RakeTask.new(:unit) do |t|
      t.pattern = "spec/unit/**/*_spec.rb"
    end

    desc 'Run tests that require a host System Under Test configured with WinRM'
    RSpec::Core::RakeTask.new(:winrm) do |t|
      t.rspec_opts = '--tag winrm'
    end

    desc 'Run tests that require a host System Under Test configured with SSH'
    RSpec::Core::RakeTask.new(:ssh) do |t|
      t.rspec_opts = '--tag ssh'
    end

    desc 'Run tests that require a host System Under Test configured with Docker'
    RSpec::Core::RakeTask.new(:docker) do |t|
      t.rspec_opts = '--tag docker'
    end

    desc 'Run tests that require Bash on the local host'
    RSpec::Core::RakeTask.new(:bash) do |t|
      t.rspec_opts = '--tag bash'
    end

    desc 'Run tests that require Windows on the local host'
    RSpec::Core::RakeTask.new(:windows) do |t|
      t.rspec_opts = '--tag windows'
    end
  end

  # The following tasks are run during CI and require additional environment setup
  # to run. Jobs that run these tests can be viewed in .github/workflows/
  namespace :ci do
    namespace :apply do
      desc ''
      RSpec::Core::RakeTask.new(:linux) do |t|
        t.pattern = "spec/integration/**/*_spec.rb"
        t.exclude_pattern = "spec/integration/transport/*"
        t.rspec_opts = generate_opts(include_tags: %w[apply],
                                     exclude_tags: %w[docker winrm])
      end

      desc ''
      RSpec::Core::RakeTask.new(:windows) do |t|
        t.pattern = "spec/integration/**/*_spec.rb"
        t.exclude_pattern = "spec/integration/transport/*"
        exclude = %w[bash docker puppetdb ssh winrm_agentless]
        t.rspec_opts = generate_opts(include_tags: %w[apply], exclude_tags: exclude)
      end
    end

    namespace :boltserver do
      desc ''
      RSpec::Core::RakeTask.new(:linux) do |t|
        t.pattern = "spec/bolt_server/**/*_spec.rb"
        t.rspec_opts = '--tag ~winrm'
      end

      desc ''
      RSpec::Core::RakeTask.new(:windows) do |t|
        t.pattern = "spec/bolt_server/**/*_spec.rb"
        t.rspec_opts = '--tag ~ssh --tag ~puppetserver'
      end
    end

    namespace :boltspec do
      desc ''
      RSpec::Core::RakeTask.new(:linux) do |t|
        t.pattern = "spec/bolt_spec/**/*_spec.rb"
      end

      desc ''
      RSpec::Core::RakeTask.new(:windows) do |t|
        t.pattern = "spec/bolt_spec/**/*_spec.rb"
        t.rspec_opts = '--tag ~ssh'
      end
    end

    desc ''
    RSpec::Core::RakeTask.new(:docker_transport) do |t|
      t.pattern = "spec/integration/transport/docker_spec.rb"
    end

    namespace :local_transport do
      desc ''
      RSpec::Core::RakeTask.new(:linux) do |t|
        t.pattern = "spec/integration/transport/local_spec.rb"
      end

      desc ''
      RSpec::Core::RakeTask.new(:windows) do |t|
        t.pattern = "spec/integration/transport/local_spec.rb"
        t.rspec_opts = '--tag ~sudo'
      end
    end

    desc ''
    RSpec::Core::RakeTask.new(:orch_transport) do |t|
      t.pattern = "spec/integration/transport/orch_spec.rb"
    end

    desc ''
    RSpec::Core::RakeTask.new(:ssh_transport) do |t|
      t.pattern = "spec/integration/transport/ssh_spec.rb"
    end

    desc ''
    RSpec::Core::RakeTask.new(:winrm_transport) do |t|
      t.pattern = "spec/integration/transport/winrm_spec.rb"
    end

    namespace :linux do
      desc ''
      RSpec::Core::RakeTask.new(:integration) do |t|
        t.pattern = "spec/integration/**/*_spec.rb"
        t.exclude_pattern = "spec/integration/transport/*"
        exclude = %w[winrm apply]
        t.rspec_opts = generate_opts(exclude_tags: exclude)
      end
    end

    namespace :windows do
      desc ''
      RSpec::Core::RakeTask.new(:agentless) do |t|
        t.pattern = "spec/integration/**/*_spec.rb"
        t.exclude_pattern = "spec/integration/transport/*"
        t.rspec_opts = '--tag winrm_agentless'
      end

      desc ''
      RSpec::Core::RakeTask.new(:integration) do |t|
        t.pattern = "spec/integration/**/*_spec.rb"
        t.exclude_pattern = "spec/integration/transport/*"
        exclude = %w[apply bash docker puppetdb ssh sudo winrm_agentless]
        t.rspec_opts = generate_opts(exclude_tags: exclude)
      end
    end

    desc "Run RSpec tests for Bolt's bundled content"
    task :modules do
      success = true
      # Test core modules
      Pathname.new("#{__dir__}/../bolt-modules").each_child do |mod|
        Dir.chdir(mod) do
          sh 'rake spec' do |ok, _|
            success = false unless ok
          end
        end
      end
      # Test modules
      %w[canary aggregate puppetdb_fact puppet_connect].each do |mod|
        Dir.chdir("#{__dir__}/../modules/#{mod}") do
          sh 'rake spec' do |ok, _|
            success = false unless ok
          end
        end
      end
      # Test BoltSpec
      Dir.chdir("#{__dir__}/../bolt_spec_spec/") do
        sh 'rake spec' do |ok, _|
          success = false unless ok
        end
      end
      raise "Module tests failed" unless success
    end
  end
rescue LoadError
end
# rubocop:enable Lint/SuppressedException
