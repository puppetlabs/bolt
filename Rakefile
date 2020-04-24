# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"
require "bolt/cli"

require "puppet-strings"
require "fileutils"
require "json"
require "erb"

# Needed for Vanagon component ship job
# Do not load in GitHub workflows
unless ENV['GITHUB_WORKFLOW']
  require 'packaging'
  Pkg::Util::RakeUtils.load_packaging_tasks
end

desc "Run all RSpec tests"
RSpec::Core::RakeTask.new(:spec)

desc "Run RSpec tests that don't require VM fixtures or a particular shell"
RSpec::Core::RakeTask.new(:unit) do |t|
  t.rspec_opts = '--tag ~ssh --tag ~docker --tag ~bash --tag ~winrm ' \
                 '--tag ~windows_agents --tag ~puppetserver --tag ~puppetdb ' \
                 '--tag ~omi --tag ~kerberos'
end

desc "Run RSpec tests for Windows that don't require SSH, Bash, Windows Puppet Agents, or orchestrator"
RSpec::Core::RakeTask.new(:windows_ci) do |t|
  t.rspec_opts = '--tag ~ssh --tag ~docker --tag ~bash --tag ~windows_agents ' \
         '--tag ~orchestrator --tag ~puppetserver --tag ~puppetdb --tag ~omi ' \
         '--tag ~kerberos'
end

desc "Run RSpec tests for CI that don't require WinRM"
RSpec::Core::RakeTask.new(:fast) do |t|
  t.rspec_opts = '--tag ~winrm --tag ~windows_agents --tag ~puppetserver --tag ~puppetdb ' \
  '--tag ~omi --tag ~windows --tag ~kerberos --tag ~expensive'
end

desc "Run RSpec tests that are slow or require slow to start containers for setup"
RSpec::Core::RakeTask.new(:slow) do |t|
  t.rspec_opts = '--tag puppetserver --tag puppetdb --tag expensive'
end

task :bolt_spec do
  Dir.chdir("#{__dir__}/bolt_spec_spec/") do
    sh "rake spec"
  end
end

RuboCop::RakeTask.new(:rubocop) do |t|
  t.options = ['--display-cop-names', '--display-style-guide', '--parallel']
end

desc "Run tests and style checker"
task test: %w[spec rubocop]

task :default do
  system "rake --tasks"
end

def format_links(text)
  text.gsub(/{([^}]+)}/, '[`\1`](#\1)')
end

namespace :ci do
  task :fast do
    Rake::Task['fast'].invoke
    Rake::Task['bolt_spec'].invoke
  end

  task :slow do
    Rake::Task['slow'].invoke
  end

  task :modules do
    success = true
    # Test core modules
    %w[boltlib ctrl file out prompt system].each do |mod|
      Dir.chdir("#{__dir__}/bolt-modules/#{mod}") do
        sh 'rake spec' do |ok, _|
          success = false unless ok
        end
      end
    end
    # Test modules
    %w[canary aggregate puppetdb_fact].each do |mod|
      Dir.chdir("#{__dir__}/modules/#{mod}") do
        sh 'rake spec' do |ok, _|
          success = false unless ok
        end
      end
    end
    raise "Module tests failed" unless success
  end
end

namespace :docs do
  desc "Generate markdown docs for Bolt's transport configuration options"
  task :config_reference do
    @transports = { options: {}, defaults: {} }
    @global = { options: Bolt::Config::OPTIONS, defaults: Bolt::Config::DEFAULT_OPTIONS }
    @log = { options: Bolt::Config::LOG_OPTIONS, defaults: Bolt::Config::DEFAULT_LOG_OPTIONS }
    @puppetfile = { options: Bolt::Config::PUPPETFILE_OPTIONS }
    @apply = { options: Bolt::Config::APPLY_SETTINGS, defaults: Bolt::Config::DEFAULT_APPLY_SETTINGS }

    Bolt::Config::TRANSPORT_CONFIG.each do |name, transport|
      @transports[:options][name] = transport::OPTIONS
      @transports[:defaults][name] = transport::DEFAULTS
    end

    renderer = ERB.new(File.read('documentation/bolt_configuration_reference.md.erb'), nil, '-')
    File.write('documentation/bolt_configuration_reference.md', renderer.result)
  end

  desc "Generate markdown docs for Bolt's command line options"
  task :cli_reference do
    parser = Bolt::BoltOptionParser.new({})
    @commands = {}

    Bolt::CLI::COMMANDS.each do |subcommand, actions|
      actions << nil if actions.empty?

      actions.each do |action|
        command = [subcommand, action].compact.join(' ')
        help_text = parser.get_help_text(subcommand, action)
        matches = help_text[:banner].match(/USAGE(?<usage>.+?)DESCRIPTION(?<desc>.+?)(EXAMPLES|\z)/m)

        options = help_text[:flags].map do |option|
          switch = parser.top.long[option]

          {
            short: switch.short.first,
            long: switch.long.first,
            arg: switch.arg,
            desc: switch.desc.map { |d| d.gsub("<", "&lt;") }.join("<br>")
          }
        end

        desc  = matches[:desc].split("\n").map(&:strip).join("\n")
        usage = matches[:usage].strip

        @commands[command] = {
          usage: usage,
          desc: desc,
          options: options
        }
      end
    end

    # It's nice to have the subcommands/actions sorted alphabetically in the docs
    # We could get around this by sorting the COMMANDS hash in the CLI
    @commands = @commands.sort.to_h

    renderer = ERB.new(File.read('documentation/bolt_command_reference.md.erb'), nil, '-')
    File.write('documentation/bolt_command_reference.md', renderer.result)
  end

  desc "Generate markdown docs for Bolt's core Puppet functions"
  task :function_reference do
    FileUtils.mkdir_p 'tmp'
    tmpfile = 'tmp/boltlib.json'
    PuppetStrings.generate(['bolt-modules/*'],
                           markup: 'markdown', json: true, path: tmpfile,
                           yard_args: ['bolt-modules/boltlib',
                                       'bolt-modules/ctrl',
                                       'bolt-modules/file',
                                       'bolt-modules/out',
                                       'bolt-modules/prompt',
                                       'bolt-modules/system'])
    json = JSON.parse(File.read(tmpfile))
    funcs = json.delete('puppet_functions')
    json.delete('data_types')
    json.each { |k, v| raise "Expected #{k} to be empty, found #{v}" unless v.empty? }

    # @functions will be a list of function descriptions, structured as
    #   name: function name
    #   text: function description; first line should be usable as a summary
    #   signatures: a list of function overloads
    #     text: overload description
    #     signature: function signature
    #     returns: list of return statements
    #       text: return description
    #       types: list of types (probably only one entry)
    #     params: list of params
    #       name: parameter name
    #       text: description
    #       types: list of types (probably only one entry)
    #     examples: list of examples
    #       name: description
    #       text: example body
    @functions = funcs.map do |func|
      func['text'] = func['docstring']['text']

      overloads = func['docstring']['tags'].select { |tag| tag['tag_name'] == 'overload' }
      sig_tags = overloads.map { |overload| overload['docstring']['tags'] }
      sig_tags = [func['docstring']['tags']] if sig_tags.empty?
      func['signatures'] = func['signatures'].zip(sig_tags).map do |sig, tags|
        sig['text'] = sig['docstring']['text']
        sects = sig['docstring']['tags'].group_by { |t| t['tag_name'] }
        sig['returns'] = sects['return'].map do |ret|
          ret['text'] = format_links(ret['text'])
          ret
        end
        sig['params'] = sects['param'].map do |param|
          param['text'] = format_links(param['text'])
          param
        end
        if sects['option']
          sig['options'] = sects['option'].map do |option|
            option['opt_text'] = format_links(option['opt_text'])
            option
          end
        end

        # get examples from overload docstring; puppet-strings should probably do this.
        examples = tags.select { |t| t['tag_name'] == 'example' }
        sig['examples'] = examples
        sig.delete('docstring')
        sig
      end

      func
    end
    renderer = ERB.new(File.read('documentation/reference.md.erb'), nil, '-')
    File.write('documentation/plan_functions.md', renderer.result)
  end

  task all: %i[cli_reference function_reference config_reference]
end

desc 'Generate all markdown docs'
task generate_docs: 'docs:all'

namespace :integration do
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

  desc 'Run tests that require windows OS on the local host'
  RSpec::Core::RakeTask.new(:windows) do |t|
    t.rspec_opts = '--tag windows'
  end

  desc 'Run tests that require Puppet Agents configured with Windows'
  RSpec::Core::RakeTask.new(:windows_agents) do |t|
    t.rspec_opts = '--tag windows_agents'
  end

  desc 'Run tests that require OMI docker container'
  RSpec::Core::RakeTask.new(:omi) do |t|
    t.rspec_opts = '--tag omi'
  end

  task ssh: :update_submodules
  task winrm: :update_submodules

  task :update_submodules do
    sh 'git submodule update --init'
  end
end

desc 'Generate changelog'
task :changelog, [:version] do |_t, args|
  sh "./scripts/generate_changelog.rb #{args[:version]}"
end

spec = Gem::Specification.find_by_name 'gettext-setup'
load "#{spec.gem_dir}/lib/tasks/gettext.rake"
