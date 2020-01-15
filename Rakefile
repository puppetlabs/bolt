# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "bolt/cli"

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
                 '--tag ~omi --tag ~kerberos'
end

desc "Run RSpec tests for AppVeyor that don't require SSH, Bash, Appveyor Puppet Agents, or orchestrator"
RSpec::Core::RakeTask.new(:appveyor) do |t|
  t.rspec_opts = '--tag ~ssh --tag ~docker --tag ~bash --tag ~appveyor_agents ' \
         '--tag ~orchestrator --tag ~puppetserver --tag ~puppetdb --tag ~omi ' \
         '--tag ~kerberos'
end

desc "Run RSpec tests for TravisCI that don't require WinRM"
RSpec::Core::RakeTask.new(:travisci) do |t|
  t.rspec_opts = '--tag ~winrm --tag ~appveyor_agents --tag ~puppetserver --tag ~puppetdb ' \
  '--tag ~omi --tag ~windows --tag ~kerberos --tag ~expensive'
end

desc "Run RSpec tests that are slow or require slow to start containers for setup"
RSpec::Core::RakeTask.new(:puppetserver) do |t|
  t.rspec_opts = '--tag puppetserver --tag puppetdb --tag expensive'
end

desc "Run tests and style checker"
task test: %w[spec]

task :default do
  system "rake --tasks"
end

def format_links(text)
  text.gsub(/{([^}]+)}/, '[`\1`](#\1)')
end

namespace :travis do
  task :unit do
    sh "docker-compose -f spec/docker-compose.yml build --parallel ubuntu_node puppet_5_node puppet_6_node"
    sh "docker-compose -f spec/docker-compose.yml up -d ubuntu_node puppet_5_node puppet_6_node"
    sh "r10k puppetfile install"
    Rake::Task['travisci'].invoke
  end
  task :modules do
    success = true
    %w[boltlib ctrl file out system].each do |mod|
      Dir.chdir("#{__dir__}/bolt-modules/#{mod}") do
        sh 'rake spec' do |ok, _|
          success = false unless ok
        end
      end
    end
    raise "Module tests failed" unless success
  end
  task docs: :generate_docs
  task :integration do
    sh "docker-compose -f spec/docker-compose.yml build --parallel"
    sh "docker-compose -f spec/docker-compose.yml up -d"
    sh "r10k puppetfile install"
    # Wait for containers to be started
    result = 15.times do
      ready = sh('[ -z "$(docker ps -q --filter=health=starting)" ]') { |ok, _| ok }
      break :ready if ready
      sleep(5)
    end
    if result == :ready
      Rake::Task['puppetserver'].invoke
    else
      raise "Containers did not properly start"
    end
  end
end

namespace :docs do
  desc "Generate markdown docs for Bolt's command line options"
  task :cli_reference do
    parser = Bolt::BoltOptionParser.new({})
    @commands = {}

    Bolt::CLI::COMMANDS.each do |subcommand, actions|
      actions << nil if actions.empty?

      actions.each do |action|
        command = [subcommand, action].compact.join(' ')
        help_text = parser.get_help_text(subcommand, action)

        options = help_text[:flags].map do |option|
          switch = parser.top.long[option]

          {
            short: switch.short.first,
            long: switch.long.first,
            arg: switch.arg,
            desc: switch.desc.map { |d| d.gsub("<", "&lt;") }.join("<br>")
          }
        end

        @commands[command] = {
          banner: help_text[:banner],
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

  task all: %i[cli_reference function_reference]
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
