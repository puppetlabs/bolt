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

def generate_yaml_file(data)
  data.each_with_object({}) do |(option, definition), acc|
    if definition.key?(:_example)
      acc[option] = definition[:_example]
    elsif definition.key?(:properties)
      acc[option] = generate_yaml_file(definition[:properties])
    end
  end
end

def stringify_types(data)
  if data.key?(:type)
    types = Array(data[:type])

    if types.include?(TrueClass) || types.include?(FalseClass)
      types = types - [TrueClass, FalseClass] + ['Boolean']
    end

    data[:type] = types.join(', ')
  end

  if data.key?(:properties)
    data[:properties] = data[:properties].transform_values do |d|
      stringify_types(d)
    end
  end

  data
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
  desc 'Generate markdown docs for bolt.yaml'
  task :config_reference do
    @opts      = Bolt::Config::OPTIONS.slice(*Bolt::Config::BOLT_OPTIONS)
    @inventory = Bolt::Config::INVENTORY_OPTIONS.dup

    # Move sub-options for 'log' option up one level, as they're nested under
    # 'console' and filepath
    @opts['log'][:properties] = @opts['log'][:additionalProperties][:properties]

    # Stringify data types
    @opts.transform_values! { |data| stringify_types(data) }
    @inventory.transform_values! { |data| stringify_types(data) }

    # Generate YAML file examples
    @yaml           = generate_yaml_file(@opts)
    @inventory_yaml = generate_yaml_file(@inventory)

    renderer = ERB.new(File.read('documentation/templates/bolt_configuration_reference.md.erb'), nil, '-')
    File.write('documentation/bolt_configuration_reference.md', renderer.result)
  end

  desc 'Generate privilege escalation document'
  task :privilege_escalation do
    @run_as = Bolt::Config::Transport::Options::TRANSPORT_OPTIONS.slice(
      *Bolt::Config::Transport::Options::RUN_AS_OPTIONS
    )

    @run_as.transform_values! { |data| stringify_types(data) }

    parser = Bolt::BoltOptionParser.new({})
    @run_as_options = Bolt::BoltOptionParser::OPTIONS[:escalation].map do |option|
      switch = parser.top.long[option]

      {
        long: switch.long.first,
        arg: switch.arg,
        desc: switch.desc.map { |d| d.gsub("<", "&lt;") }.join("<br>")
      }
    end

    renderer = ERB.new(File.read('documentation/templates/privilege_escalation.md.erb'), nil, '-')
    File.write('documentation/privilege_escalation.md', renderer.result)
  end

  desc 'Generate markdown docs for bolt-project.yaml'
  task :project_reference do
    @opts = Bolt::Config::OPTIONS.slice(*Bolt::Config::BOLT_PROJECT_OPTIONS)

    # Move sub-options for 'log' option up one level, as they're nested under
    # 'console' and filepath
    @opts['log'][:properties] = @opts['log'][:additionalProperties][:properties]

    # Stringify data types
    @opts.transform_values! { |data| stringify_types(data) }

    # Generate YAML file examples
    @yaml = generate_yaml_file(@opts)

    renderer = ERB.new(File.read('documentation/templates/bolt_project_reference.md.erb'), nil, '-')
    File.write('documentation/bolt_project_reference.md', renderer.result)
  end

  desc 'Generate markdown docs for bolt-defaults.yaml'
  task :defaults_reference do
    @opts       = Bolt::Config::OPTIONS.slice(*Bolt::Config::BOLT_DEFAULTS_OPTIONS)
    inventory   = Bolt::Config::INVENTORY_OPTIONS.dup
    @transports = Bolt::Config::TRANSPORT_CONFIG.keys

    # Stringify data types
    @opts.transform_values! { |data| stringify_types(data) }

    # Generate YAML file examples
    @yaml          = generate_yaml_file(@opts)
    inventory_yaml = generate_yaml_file(inventory)

    # Add inventory examples to 'inventory-config'
    @yaml['inventory-config'] = inventory_yaml

    renderer = ERB.new(File.read('documentation/templates/bolt_defaults_reference.md.erb'), nil, '-')
    File.write('documentation/bolt_defaults_reference.md', renderer.result)
  end

  desc 'Generate markdown docs for transports configuration reference'
  task :transports_reference do
    @opts = Bolt::Config::INVENTORY_OPTIONS.dup
    @nativessh = Bolt::Config::Transport::Options::TRANSPORT_OPTIONS.slice(
      *Bolt::Config::Transport::SSH::NATIVE_OPTIONS
    )

    # Stringify data types
    @opts.transform_values! { |data| stringify_types(data) }

    # Add sub-options for each of the transport options
    Bolt::Config::TRANSPORT_CONFIG.each do |name, transport|
      # Only include suboption examples in the full example, not under individual suboption sections
      @opts[name].delete(:_example)
      # Pull out sub-options for each transport
      suboptions = transport::TRANSPORT_OPTIONS.slice(*transport::OPTIONS)
      # Add the sub-options as properties for the transport option
      @opts[name][:properties] = suboptions.transform_values { |data| stringify_types(data) }
    end

    # The 'local' transport's options are platform-dependent, so pull out the list for each
    @local_sets = {
      nix: Bolt::Config::Transport::Local::OPTIONS,
      win: Bolt::Config::Transport::Local::WINDOWS_OPTIONS
    }

    # Stringify types for the native SSH transport
    @nativessh.transform_values! { |data| stringify_types(data) }

    # Generate YAML file examples
    @yaml = generate_yaml_file(@opts)

    renderer = ERB.new(File.read('documentation/templates/bolt_transports_reference.md.erb'), nil, '-')
    File.write('documentation/bolt_transports_reference.md', renderer.result)
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

    renderer = ERB.new(File.read('documentation/templates/bolt_command_reference.md.erb'), nil, '-')
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
    renderer = ERB.new(File.read('documentation/templates/reference.md.erb'), nil, '-')
    File.write('documentation/plan_functions.md', renderer.result)
  end

  task all: %i[
    cli_reference
    function_reference
    config_reference
    privilege_escalation
    project_reference
    defaults_reference
    transports_reference
  ]
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

namespace :pwsh do
  desc "Generate pwsh from Bolt's command line options"
  task :generate_module do
    # https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands?view=powershell-7
    @pwsh_verbs = {
      'apply'      => 'Invoke',
      'convert'    => 'Convert',
      'createkeys' => 'New',
      'init'       => 'New',
      'install'    => 'Install',
      'encrypt'    => 'Protect',
      'decrypt'    => 'Unprotect',
      'migrate'    => 'Update',
      'run'        => 'Invoke',
      'show'       => 'Get',
      'upload'     => 'Send' # deploy? publish?
    }

    @hardcoded_cmdlets = {
      'createkeys' => {
        'verb' => 'New',
        'noun' => 'BoltSecretKey'
      },
      'show-modules' => {
        'verb' => 'Get',
        'noun' => 'BoltPuppetfileModules'
      },
      'generate-types' => {
        'verb' => 'Register',
        'noun' => 'BoltPuppetfileTypes'
      }
    }

    parser = Bolt::BoltOptionParser.new({})

    @commands = []
    Bolt::CLI::COMMANDS.each do |subcommand, actions|
      actions << nil if actions.empty?
      actions.each do |action|
        help_text = parser.get_help_text(subcommand, action)
        matches = help_text[:banner].match(/USAGE(?<usage>.+?)DESCRIPTION(?<desc>.+?)(EXAMPLES|\z)/m)
        action.chomp unless action.nil?

        if action.nil? && subcommand == 'apply'
          cmdlet_verb = 'Invoke'
          cmdlet_noun = "Bolt#{subcommand.capitalize}"
        elsif @hardcoded_cmdlets[action]
          cmdlet_verb = @hardcoded_cmdlets[action]['verb']
          cmdlet_noun = @hardcoded_cmdlets[action]['noun']
        else
          cmdlet_verb = @pwsh_verbs[action]
          cmdlet_noun = "Bolt#{subcommand.capitalize}"
        end

        if cmdlet_verb.nil?
          throw "Unable to map #{subcommand} #{action} to PowerShell verb. \
                Review configured mappings and add new action to verb mapping"
        end

        @pwsh_command = {
          cmdlet:       "#{cmdlet_verb}-#{cmdlet_noun}",
          verb:         cmdlet_verb,
          noun:         cmdlet_noun,
          ruby_command: subcommand,
          ruby_action:  action,
          description:  matches[:desc].strip,
          syntax:       matches[:usage].strip
        }

        @pwsh_command[:options] = []

        case subcommand
        when 'apply'
          # bolt apply [manifest.pp] [options]
          # Cannot use bolt apply manifest.pp with --execute
          @pwsh_command[:options] << {
            name:                       'manifest',
            parameter_set:              'manifest',
            help_msg:                   'The manifest to apply',
            type:                       'string',
            switch:                     false,
            mandatory:                  true,
            position:                   0,
            ruby_arg:                   'bare',
            validate_not_null_or_empty: true
          }
        when 'command'
          # bolt command run <command> [options]
          @pwsh_command[:options] << {
            name:                       'command',
            help_msg:                   'The command to execute',
            type:                       'string',
            switch:                     false,
            mandatory:                  true,
            position:                   0,
            ruby_arg:                   'bare',
            validate_not_null_or_empty: true
          }
        when 'script'
          # bolt command run <script> [options]
          @pwsh_command[:options] << {
            name:                       'script',
            help_msg:                   'The script to execute',
            type:                       'string',
            switch:                     false,
            mandatory:                  true,
            position:                   0,
            ruby_arg:                   'bare',
            validate_not_null_or_empty: true
          }
          @pwsh_command[:options] << {
            name:      'arguments',
            help_msg:  'The arguments to the script',
            type:      'string',
            switch:    false,
            mandatory: false,
            position:  1,
            ruby_arg:  'bare'
          }
        when 'task'
          # bolt task show|run <task> [parameters] [options]
          task_param_mandatory = (@pwsh_command[:verb] != 'Get')
          @pwsh_command[:options] << {
            name:                       'task',
            help_msg:                   "The task to #{action}",
            type:                       'string',
            switch:                     false,
            mandatory:                  task_param_mandatory,
            position:                   0,
            ruby_arg:                   'bare',
            validate_not_null_or_empty: true
          }

        when 'plan'
          # bolt plan show [plan] [options]
          # bolt plan run <plan> [parameters] [options]
          # bolt plan convert <path> [options]
          @pwsh_command[:options] << {
            name:                       'plan',
            help_msg:                   "The plan to #{action}",
            type:                       'string',
            switch:                     false,
            mandatory:                  false,
            position:                   0,
            ruby_arg:                   'bare',
            validate_not_null_or_empty: true
          }
        when 'file'
          # bolt file upload <src> <dest> [options]
          @pwsh_command[:options] << {
            name:                       'source',
            help_msg:                   'The source file or directory to upload',
            type:                       'string',
            switch:                     false,
            mandatory:                  true,
            position:                   0,
            ruby_arg:                   'bare',
            validate_not_null_or_empty: true
          }
          @pwsh_command[:options] << {
            name:                       'destination',
            type:                       'string',
            switch:                     false,
            mandatory:                  true,
            position:                   1,
            help_msg:                   'The destination to upload to',
            ruby_arg:                   'bare',
            validate_not_null_or_empty: true
          }
        when 'secret'
          # bolt secret encrypt <plaintext> [options]
          # bolt secret decrypt <ciphertext> [options]
          @pwsh_command[:options] << {
            name:                       'text',
            help_msg:                   "The text to #{action}",
            type:                       'string',
            switch:                     false,
            mandatory:                  true,
            position:                   0,
            ruby_arg:                   'bare',
            validate_not_null_or_empty: true
          }
        when 'project'
          # bolt project init [directory] [options]
          @pwsh_command[:options] << {
            name:                       'directory',
            help_msg:                   'The directory to turn into a Bolt project',
            mandatory:                  false,
            type:                       'string',
            switch:                     false,
            position:                   0,
            ruby_arg:                   'bare',
            validate_not_null_or_empty: true
          }
        end

        # verbose and debug are commonparameters and are already present in the
        # pwsh cmdlets, so they are omitted here to prevent them from being
        # added twice we add these back in when building the command to send to bolt
        help_text[:flags].reject { |o| o =~ /verbose|debug|help/ }.map do |option|
          ruby_param = parser.top.long[option]
          pwsh_name = option.gsub("-", "")

          next if pwsh_name == 'version'

          pwsh_param = {
            name:       pwsh_name,
            type:       'string',
            switch:     false,
            mandatory:  false,
            help_msg:   ruby_param.desc.map { |d| d.gsub("<", "&lt;") }.join("\n"),
            ruby_short: ruby_param.short.first,
            ruby_long:  ruby_param.long.first,
            ruby_arg:   ruby_param.arg,
            ruby_orig:  option
          }

          case ruby_param.class.to_s
          when 'OptionParser::Switch::RequiredArgument'
            # this isn't quite the same thing as a mandatory pwsh parameter
          when 'OptionParser::Switch::OptionalArgument'
            pwsh_param[:mandatory] = false
          when 'OptionParser::Switch::NoArgument'
            pwsh_param[:mandatory] = false
            pwsh_param[:switch] = true
            pwsh_param[:type] = 'switch'
          end

          # Only one of --targets , --rerun , or --query can be used
          # Only one of --configfile or --boltdir can be used
          case pwsh_name
          when 'user'
            pwsh_param[:validate_not_null_or_empty] = true
          when 'password'
            pwsh_param[:validate_not_null_or_empty] = true
          when 'privatekey'
            pwsh_param[:validate_not_null_or_empty] = true
          when 'concurrency'
            pwsh_param[:validate_not_null_or_empty] = true
          when 'compileconcurrency'
            pwsh_param[:validate_not_null_or_empty] = true
          when 'connecttimeout'
            pwsh_param[:validate_not_null_or_empty] = true
          when 'modulepath'
            pwsh_param[:validate_not_null_or_empty] = true
          when 'transport'
            pwsh_param[:validate_set] = Bolt::Config::Options::TRANSPORT_CONFIG.keys
          when 'targets'
            pwsh_param[:validate_not_null_or_empty] = true
          when 'query'
            pwsh_param[:validate_not_null_or_empty] = true
          when 'rerun'
            pwsh_param[:validate_not_null_or_empty] = true
          when 'configfile'
            pwsh_param[:validate_not_null_or_empty] = true
          when 'boltdir'
            pwsh_param[:validate_not_null_or_empty] = true
          when 'execute'
            pwsh_param[:parameter_set] = 'execute'
            pwsh_param[:mandatory] = true
            pwsh_param[:position] = 0
          when 'params'
            pwsh_param[:position] = 1
            pwsh_param[:type] = nil
          when 'modules'
            pwsh_param[:type] = nil
          when 'format'
            pwsh_param[:validate_set] = %w[human json rainbow]
          end

          @pwsh_command[:options] << pwsh_param
        end

        @commands << @pwsh_command
      end
    end

    renderer = ERB.new(File.read('pwsh_module/pwsh_bolt.psm1.erb'), nil, '-')
    File.write('pwsh_module/pwsh_bolt.psm1', renderer.result)

    tests = ERB.new(File.read('pwsh_module/pwsh_bolt.tests.ps1.erb'), nil, '-')
    File.write("pwsh_module/autogenerated.tests.ps1", tests.result)

    docs = ERB.new(File.read('documentation/templates/bolt_pwsh_reference.md.erb'), nil, '-')
    File.write("documentation/bolt_pwsh_reference.md", docs.result)
  end
end
