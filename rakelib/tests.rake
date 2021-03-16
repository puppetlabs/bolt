# frozen_string_literal: true

# rubocop:disable Lint/SuppressedException
begin
  require 'rspec/core/rake_task'

  namespace :tests do
    desc "Run all RSpec tests"
    RSpec::Core::RakeTask.new(:spec)

    desc "Run RSpec tests that do not require VM fixtures or a particular shell"
    RSpec::Core::RakeTask.new(:unit) do |t|
      t.rspec_opts = '--tag ~ssh --tag ~docker --tag ~lxd_transport --tag ~bash --tag ~winrm ' \
                     '--tag ~windows_agents --tag ~puppetserver --tag ~puppetdb ' \
                     '--tag ~omi --tag ~kerberos --tag ~lxd_remote'
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

    desc 'Run tests that require a host System Under Test configured with LXD'
    RSpec::Core::RakeTask.new(:lxd) do |t|
      t.rspec_opts = '--tag lxd_transport'
    end

    desc 'Run tests that require a host System Under Test configured with LXD remote'
    RSpec::Core::RakeTask.new(:lxd_remote) do |t|
      t.rspec_opts = '--tag lxd_remote'
    end

    desc 'Run tests that require Bash on the local host'
    RSpec::Core::RakeTask.new(:bash) do |t|
      t.rspec_opts = '--tag bash'
    end

    desc 'Run tests that require Windows on the local host'
    RSpec::Core::RakeTask.new(:windows) do |t|
      t.rspec_opts = '--tag windows'
    end

    desc 'Run tests that require OMI docker container'
    RSpec::Core::RakeTask.new(:omi) do |t|
      t.rspec_opts = '--tag omi'
    end
  end

  # The following tasks are run during CI and require additional environment setup
  # to run. Jobs that run these tests can be viewed in .github/workflows/
  namespace :ci do
    namespace :linux do
      # Run RSpec tests that do not require WinRM
      desc ''
      RSpec::Core::RakeTask.new(:fast) do |t|
        t.rspec_opts = '--tag ~winrm --tag ~lxd_transport --tag ~windows_agents --tag ~puppetserver ' \
                       '--tag ~puppetdb --tag ~omi --tag ~windows --tag ~kerberos --tag ~expensive ' \
                       '--tag ~lxd_remote'
      end

      # Run RSpec tests that are slow or require slow to start containers for setup
      desc ''
      RSpec::Core::RakeTask.new(:slow) do |t|
        t.rspec_opts = '--tag puppetserver --tag puppetdb --tag expensive'
      end
    end

    namespace :windows do
      # Run RSpec tests that do not require Puppet Agents on Windows
      desc ''
      RSpec::Core::RakeTask.new(:agentless) do |t|
        t.rspec_opts = '--tag ~ssh --tag ~docker --tag ~lxd_transport --tag ~bash --tag ~windows_agents ' \
                       '--tag ~orchestrator --tag ~puppetserver --tag ~puppetdb --tag ~omi ' \
                       '--tag ~kerberos --tag ~lxd_remote'
      end

      # Run RSpec tests that require Puppet Agents configured with Windows
      desc ''
      RSpec::Core::RakeTask.new(:agentful) do |t|
        t.rspec_opts = '--tag windows_agents'
      end
    end

    desc "Run RSpec tests for Bolt's bundled content"
    task :modules do
      success = true
      # Test core modules
      %w[boltlib ctrl file dir out prompt system].each do |mod|
        Dir.chdir("#{__dir__}/../bolt-modules/#{mod}") do
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
