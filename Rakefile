# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

require "puppet-strings"
require "fileutils"
require "json"
require "erb"

# Needed for Vanagon component ship job
require 'packaging'
Pkg::Util::RakeUtils.load_packaging_tasks

desc "Run all RSpec tests"
RSpec::Core::RakeTask.new(:spec)

desc "Run RSpec tests that don't require VM fixtures or a particular shell"
RSpec::Core::RakeTask.new(:unit) do |t|
  t.rspec_opts = '--tag ~ssh --tag ~docker --tag ~bash --tag ~winrm ' \
                 '--tag ~appveyor_agents --tag ~puppetserver --tag ~puppetdb ' \
                 '--tag ~omi'
end

desc "Run RSpec tests for AppVeyor that don't require SSH, Bash, Appveyor Puppet Agents, or orchestrator"
RSpec::Core::RakeTask.new(:appveyor) do |t|
  t.rspec_opts = '--tag ~ssh --tag ~docker --tag ~bash --tag ~appveyor_agents ' \
         '--tag ~orchestrator --tag ~puppetserver --tag ~puppetdb --tag ~omi'
end

desc "Run RSpec tests for TravisCI that don't require WinRM"
RSpec::Core::RakeTask.new(:travisci) do |t|
  t.rspec_opts = '--tag ~winrm --tag ~appveyor_agents --tag ~puppetserver --tag ~puppetdb ' \
  '--tag ~omi --tag ~windows'
end

desc "Run RSpec tests that require slow to start puppet containers"
RSpec::Core::RakeTask.new(:puppetserver) do |t|
  t.rspec_opts = '--tag puppetserver --tag puppetdb --tag omi'
end

RuboCop::RakeTask.new(:rubocop) do |t|
  t.options = ['--display-cop-names', '--display-style-guide']
end

desc "Run tests and style checker"
task test: %w[spec rubocop]

task :default do
  system "rake --tasks"
end

def format_links(text)
  text.gsub(/{([^}]+)}/, '[`\1`](#\1)')
end

desc "Generate markdown docs for Bolt's core Puppet functions"
task :docs do
  FileUtils.mkdir_p 'tmp'
  tmpfile = 'tmp/boltlib.json'
  PuppetStrings.generate(PuppetStrings::DEFAULT_SEARCH_PATTERNS,
                         markup: 'markdown', json: true, path: tmpfile,
                         yard_args: ['bolt-modules/boltlib',
                                     'bolt-modules/ctrl',
                                     'bolt-modules/file',
                                     'bolt-modules/out',
                                     'bolt-modules/system'])
  json = JSON.parse(File.read(tmpfile))
  funcs = json.delete('puppet_functions')
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

      # get examples from overload docstring; puppet-strings should probably do this.
      examples = tags.select { |t| t['tag_name'] == 'example' }
      sig['examples'] = examples
      sig.delete('docstring')
      sig
    end

    func
  end
  renderer = ERB.new(File.read('pre-docs/reference.md.erb'), nil, '-')
  File.write('pre-docs/plan_functions.md', renderer.result)
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

  desc 'Run tests that require Puppet Agents configured with Appveyor'
  RSpec::Core::RakeTask.new(:appveyor_agents) do |t|
    t.rspec_opts = '--tag appveyor_agents'
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

spec = Gem::Specification.find_by_name 'gettext-setup'
load "#{spec.gem_dir}/lib/tasks/gettext.rake"
GettextSetup.initialize(File.absolute_path('locales', File.dirname(__FILE__)))
