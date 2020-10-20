# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'erb'

# rubocop:disable Lint/SuppressedException
begin
  require 'puppet-strings'

  namespace :docs do
    desc 'Generate all markdown docs'
    task all: %i[
      function_reference
      cmdlet_reference
      command_reference
      config_reference
      defaults_reference
      privilege_escalation
      project_reference
      transports_reference
    ]

    desc "Generate markdown docs for Bolt PowerShell cmdlets"
    task cmdlet_reference: 'pwsh:generate_powershell_cmdlets' do
      filepath = File.expand_path('../documentation/bolt_cmdlet_reference.md', __dir__)
      template = File.expand_path('../documentation/templates/bolt_cmdlet_reference.md.erb', __dir__)

      renderer = ERB.new(File.read(template), nil, '-')
      File.write(filepath, renderer.result)

      $stdout.puts "Generate PowerShell cmdlet reference at:\n\t#{filepath}"
    end

    desc "Generate markdown docs for Bolt shell commands"
    task :command_reference do
      require 'bolt/bolt_option_parser'

      filepath  = File.expand_path('../documentation/bolt_command_reference.md', __dir__)
      template  = File.expand_path('../documentation/templates/bolt_command_reference.md.erb', __dir__)
      parser    = Bolt::BoltOptionParser.new({})
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
              desc: switch.desc.map { |d| d.gsub("<", "&lt;") }.join("<p>")
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

      renderer = ERB.new(File.read(template), nil, '-')
      File.write(filepath, renderer.result)

      $stdout.puts "Generated shell command reference at:\n\t#{filepath}"
    end

    desc 'Generate markdown docs for bolt.yaml'
    task :config_reference do
      require 'bolt/config'

      filepath   = File.expand_path('../documentation/bolt_configuration_reference.md', __dir__)
      template   = File.expand_path('../documentation/templates/bolt_configuration_reference.md.erb', __dir__)
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

      renderer = ERB.new(File.read(template), nil, '-')
      File.write(filepath, renderer.result)

      $stdout.puts "Generated bolt.yaml reference at:\n\t#{filepath}"
    end

    desc 'Generate markdown docs for bolt-defaults.yaml'
    task :defaults_reference do
      require 'bolt/config'

      filepath    = File.expand_path('../documentation/bolt_defaults_reference.md', __dir__)
      template    = File.expand_path('../documentation/templates/bolt_defaults_reference.md.erb', __dir__)
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

      renderer = ERB.new(File.read(template), nil, '-')
      File.write(filepath, renderer.result)

      $stdout.puts "Generated bolt-defaults.yaml reference at:\n\t#{filepath}"
    end

    desc "Generate markdown docs for Bolt's core Puppet functions"
    task :function_reference do
      filepath = File.expand_path('../documentation/plan_functions.md', __dir__)
      template = File.expand_path('../documentation/templates/plan_functions.md.erb', __dir__)

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
      renderer = ERB.new(File.read(template), nil, '-')
      File.write(filepath, renderer.result)

      $stdout.puts "Generated function reference at:\n\t#{filepath}"
    end

    desc 'Generate privilege escalation docs'
    task :privilege_escalation do
      require 'bolt/config'

      filepath = File.expand_path('../documentation/privilege_escalation.md', __dir__)
      template = File.expand_path('../documentation/templates/privilege_escalation.md.erb', __dir__)

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
          desc: switch.desc.map { |d| d.gsub("<", "&lt;") }.join("<p>")
        }
      end

      renderer = ERB.new(File.read(template), nil, '-')
      File.write(filepath, renderer.result)

      $stdout.puts "Generated privilege escalation doc at:\n\t#{filepath}"
    end

    desc 'Generate markdown docs for bolt-project.yaml'
    task :project_reference do
      require 'bolt/config'

      filepath = File.expand_path('../documentation/bolt_project_reference.md', __dir__)
      template = File.expand_path('../documentation/templates/bolt_project_reference.md.erb', __dir__)
      @opts    = Bolt::Config::OPTIONS.slice(*Bolt::Config::BOLT_PROJECT_OPTIONS)

      # Move sub-options for 'log' option up one level, as they're nested under
      # 'console' and filepath
      @opts['log'][:properties] = @opts['log'][:additionalProperties][:properties]

      # Stringify data types
      @opts.transform_values! { |data| stringify_types(data) }

      # Generate YAML file examples
      @yaml = generate_yaml_file(@opts)

      renderer = ERB.new(File.read(template), nil, '-')
      File.write(filepath, renderer.result)

      $stdout.puts "Generated bolt-project.yaml reference at:\n\t#{filepath}"
    end

    desc 'Generate markdown docs for transports configuration reference'
    task :transports_reference do
      require 'bolt/config'

      filepath   = File.expand_path('../documentation/bolt_transports_reference.md', __dir__)
      template   = File.expand_path('../documentation/templates/bolt_transports_reference.md.erb', __dir__)
      @opts      = Bolt::Config::INVENTORY_OPTIONS.dup
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

      renderer = ERB.new(File.read(template), nil, '-')
      File.write(filepath, renderer.result)

      $stdout.puts "Generated transports configuration reference at:\n\t#{filepath}"
    end
  end
rescue LoadError
end
# rubocop:enable Lint/SuppressedException

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

def format_links(text)
  text.gsub(/{([^}]+)}/, '[`\1`](#\1)')
end
