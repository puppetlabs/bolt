# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'erb'
require 'net/http'
require 'bolt/util'

class PuppetfileParser
  attr_reader :local_modules, :modules

  def initialize
    @local_modules = []
    @modules       = []
  end

  def forge(_forge); end

  def moduledir(_moduledir); end

  def mod(name, args)
    case args
    when String
      @modules << [name, args]
    else
      @local_modules << [name, args]
    end
  end
end

def make_request(url)
  uri = URI.parse(url)

  # Build the client
  client = Net::HTTP.new(uri.host, uri.port)
  client.use_ssl = true

  # Build the request
  request = Net::HTTP::Get.new(uri.request_uri)

  response = client.request(request)

  case response
  when Net::HTTPOK
    response.body
  else
    raise "Error making request to #{uri}"
  end
end

# rubocop:disable Lint/SuppressedException
begin
  require 'puppet-strings'

  namespace :docs do
    desc 'Generate all markdown docs'
    task all: %i[
      function_reference
      type_reference
      cmdlet_reference
      command_reference
      defaults_reference
      privilege_escalation
      project_reference
      transports_reference
      packaged_modules
    ]

    # Generate Puppet strings for built-in functions and data types.
    # This task has no description so it does not appear in the task
    # list.
    desc ''
    task :generate_strings do
      @puppet_strings ||= begin
        FileUtils.mkdir_p('tmp')
        tmpfile = 'tmp/boltlib.json'

        PuppetStrings.generate(
          ['bolt-modules/*'],
          markup: 'markdown',
          json: true,
          path: tmpfile,
          yard_args: ['bolt-modules/boltlib',
                      'bolt-modules/ctrl',
                      'bolt-modules/dir',
                      'bolt-modules/file',
                      'bolt-modules/out',
                      'bolt-modules/prompt',
                      'bolt-modules/system']
        )

        JSON.parse(File.read(tmpfile))
      end
    end

    desc "Generate markdown docs for Bolt PowerShell cmdlets"
    task cmdlet_reference: 'pwsh:generate_powershell_cmdlets' do
      filepath = File.expand_path('../documentation/bolt_cmdlet_reference.md', __dir__)
      template = File.expand_path('../documentation/templates/bolt_cmdlet_reference.md.erb', __dir__)

      renderer = ERB.new(File.read(template), trim_mode: '-')
      File.write(filepath, renderer.result)

      $stdout.puts "Generate PowerShell cmdlet reference at:\n\t#{filepath}"
    end

    desc "Generate markdown docs for packaged modules"
    task :packaged_modules do
      filepath   = File.expand_path('../documentation/packaged_modules.md', __dir__)
      template   = File.expand_path('../documentation/templates/packaged_modules.md.erb', __dir__)
      parser     = PuppetfileParser.new
      puppetfile = File.read(File.expand_path('../Puppetfile', __dir__))

      parser.instance_eval(puppetfile)

      @forge_modules = parser.modules.sort.map do |mod|
        slug = mod.join('-').tr('/', '-')
        data = JSON.parse(make_request("https://forgeapi.puppet.com/v3/releases/#{slug}"))

        {
          name:        mod.first.tr('-', '/'),
          version:     mod.last,
          description: data['metadata']['summary'],
          url:         "https://forge.puppet.com/#{mod.first.tr('-', '/')}/#{mod.last}"
        }
      end

      @local_modules = parser.local_modules.sort.map do |mod|
        readme = make_request("https://raw.githubusercontent.com/puppetlabs/bolt/main/modules/#{mod.first}/README.md")
        match  = readme.match(/## Description(?<desc>.*)## Req/m)

        {
          name:        mod.first,
          description: match[:desc].strip,
          url:         "https://github.com/puppetlabs/bolt/tree/main/modules/#{mod.first}"
        }
      end

      renderer = ERB.new(File.read(template), trim_mode: '-')
      File.write(filepath, renderer.result)

      $stdout.puts "Generated packaged modules at:\n\t#{filepath}"
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
          matches = help_text[:banner].match(/Usage(?<usage>.+?)Description(?<desc>.+?)(Examples|\z)/m)

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

      renderer = ERB.new(File.read(template), trim_mode: '-')
      File.write(filepath, renderer.result)

      $stdout.puts "Generated shell command reference at:\n\t#{filepath}"
    end

    desc 'Generate markdown docs for bolt-defaults.yaml'
    task :defaults_reference do
      require 'bolt/config'

      filepath    = File.expand_path('../documentation/bolt_defaults_reference.md', __dir__)
      template    = File.expand_path('../documentation/templates/bolt_defaults_reference.md.erb', __dir__)
      @opts       = Bolt::Config::OPTIONS.slice(*Bolt::Config::DEFAULTS_OPTIONS)
      inventory   = Bolt::Config::INVENTORY_OPTIONS.dup
      @transports = Bolt::Config::TRANSPORT_CONFIG.keys

      # Move sub-options for 'log' option up one level, as they're nested under
      # 'console' and filepath
      @opts['log'][:properties] = @opts['log'][:additionalProperties][:properties]

      # Remove 'notice' log level. This is soft-deprecated and shouldn't appear
      # in documentation.
      @opts['log'][:properties]['level'][:enum].delete('notice')

      # Stringify data types
      @opts.transform_values! { |data| stringify_types(data) }

      # Generate YAML file examples
      @yaml          = generate_yaml_file(@opts)
      inventory_yaml = generate_yaml_file(inventory)

      # Add inventory examples to 'inventory-config'
      @yaml['inventory-config'] = inventory_yaml

      renderer = ERB.new(File.read(template), trim_mode: '-')
      File.write(filepath, renderer.result)

      $stdout.puts "Generated bolt-defaults.yaml reference at:\n\t#{filepath}"
    end

    desc "Generate markdown docs for Bolt's data types"
    task type_reference: :generate_strings do
      filepath = File.expand_path('../documentation/bolt_types_reference.md', __dir__)
      template = File.expand_path('../documentation/templates/bolt_types_reference.md.erb', __dir__)

      @types = @puppet_strings['data_types'].map do |data|
        functions = []

        # Simplify select types.
        data = Bolt::Util.walk_vals(data) do |val|
          if val.is_a?(String)
            val.gsub(/TypeReference\['(\w*)'\]/, '\1')
               .gsub(/String\[1\]/, 'String')
          else
            val
          end
        end

        # Add attributes, which are listed under the type's params
        data.dig('docstring', 'tags').each do |param|
          functions << {
            'name' => param['name'],
            'desc' => param['text'].tr("\n", ' '),
            'type' => param['types'].first
          }
        end

        # Add functions
        data['functions'].each do |func|
          if data['name'] == 'ResultSet' && func['name'] == '[]'
            type = 'Variant[Result, ApplyResult, Array[Variant[Result, ApplyResult]]]'
          else
            type = func.dig('docstring', 'tags')
                       .find { |tag| tag['tag_name'] == 'return' }
                       .fetch('types')
            type = type.first if type.is_a?(Array)
          end

          functions << {
            'name' => func['name'],
            'desc' => func.dig('docstring', 'text').tr("\n", ' '),
            'type' => type
          }
        end

        {
          'name'  => data['name'],
          'desc'  => data.dig('docstring', 'text'),
          'funcs' => functions.sort_by { |func| func['name'] }
        }
      end

      # Generate markdown file from template
      renderer = ERB.new(File.read(template), trim_mode: '-')
      File.write(filepath, renderer.result)

      $stdout.puts "Generated data type reference at:\n\t#{filepath}"
    end

    desc "Generate markdown docs for Bolt's core Puppet functions"
    task function_reference: :generate_strings do
      filepath = File.expand_path('../documentation/plan_functions.md', __dir__)
      template = File.expand_path('../documentation/templates/plan_functions.md.erb', __dir__)

      funcs = @puppet_strings.delete('puppet_functions')

      apply = {
        "name"       => "apply",
        "desc"       => "Applies a block of manifest code to the targets.\n\nApplying manifest "\
                        "code requires facts to compile a catalog. Targets must also have "\
                        "the Puppet agent package installed to apply manifest code. To prep "\
                        "targets for an apply, call the [apply_prep](#apply-prep) function before "\
                        "the apply function.\n\nTo learn more about applying manifest code from a plan, "\
                        "see [Applying manifest blocks from a Puppet "\
                        "plan](applying_manifest_blocks.md#applying-manifest-blocks-from-a-puppet-plan).\n\n"\
                        "> **Note:** The `apply` function returns a `ResultSet` object containing `ApplyResult`\n"\
                        "> objects.",
        "examples"   => [
          {
            "desc" => "Apply manifest code, logging the provided description.",
            "exmp" => "apply($targets, '_description' => 'Install Docker') {\n  include 'docker'\n}"
          },
          {
            "desc" => "Apply manifest code as another user, catching any errors.",
            "exmp" => "$apply_results = apply($targets, '_catch_errors' => true, '_run_as' => 'bolt') {\n"\
                      "  file { '/etc/puppetlabs':\n    ensure => present\n  }\n}"
          }
        ],
        "signatures" => [
          {
            "signature" => "apply($targets, $options, &block) => ResultSet",
            "return"    => "ResultSet",
            "options"   => {
              "_catch_errors" => {
                "desc" => "When `true`, returns a `ResultSet` including failed results, rather "\
                          "than failing the plan.",
                "type" => "Boolean"
              },
              "_description" => {
                "desc" => "Adds a description to the apply block, allowing you to distinguish "\
                          "apply blocks.",
                "type" => "String"
              },
              "_noop" => {
                "desc" => "When `true`, applies the manifest block in Puppet no-operation mode, "\
                          "returning a report of the changes it would make while taking no action.",
                "type" => "Boolean"
              },
              "_run_as" => {
                "desc" => "The user to apply the manifest block as. Only available for transports "\
                          "that support the `run-as` option.",
                "type" => "String"
              }
            },
            "params"    => {
              "targets" => {
                "desc" => "The targets to apply the Puppet code to.",
                "type" => "TargetSpec"
              },
              "options" => {
                "desc" => "A hash of additional options.",
                "type" => "Optional[Hash]"
              },
              "&block" => {
                "desc" => "The manifest code to apply to the targets.",
                "type" => "Callable"
              }
            }
          }
        ]
      }
      # @functions will be a list of function descriptions, structured as
      #   name: function name
      #   desc: function description
      #   signatures: a list of function overloads
      #     desc: overload description
      #     signature: function signature
      #     return: return type
      #     params: list of params
      #       name: parameter name
      #       desc: description
      #       type: type
      #   examples: list of examples
      #     desc: description
      #     exmp: example body
      @functions = funcs.map do |func|
        data = {
          'name'       => func['name'],
          'desc'       => format_links(func['docstring']['text']),
          'signatures' => [],
          'examples'   => []
        }

        func['signatures'].each do |signature|
          sig = {
            'desc' => format_links(signature.dig('docstring', 'text')),
            'params' => {},
            'options' => {}
          }

          signature.dig('docstring', 'tags').each do |tag|
            case tag['tag_name']
            when 'example'
              data['examples'].push(
                'desc' => format_links(tag['name']),
                'exmp' => tag['text']
              )
            when 'option'
              sig['options'][tag['opt_name']] = {
                'desc' => format_links(tag['opt_text']).gsub("\n", "\s"),
                'type' => format_type(tag['opt_types'].first)
              }
            when 'param'
              sig['params'][tag['name']] = {
                'desc' => format_links(tag['text']).gsub("\n", "\s"),
                'type' => format_type(tag['types'].first)
              }
            when 'return'
              sig['return'] = format_type(tag['types'].first)
            end
          end

          sig['signature'] = make_signature(func['name'], sig['params'].keys, sig['return'])

          data['signatures'].push(sig)
        end

        data
      end

      @functions << apply
      @functions.sort! { |a, b| a['name'] <=> b['name'] }

      renderer = ERB.new(File.read(template), trim_mode: '-')
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

      renderer = ERB.new(File.read(template), trim_mode: '-')
      File.write(filepath, renderer.result)

      $stdout.puts "Generated privilege escalation doc at:\n\t#{filepath}"
    end

    desc 'Generate markdown docs for bolt-project.yaml'
    task :project_reference do
      require 'bolt/config'

      filepath = File.expand_path('../documentation/bolt_project_reference.md', __dir__)
      template = File.expand_path('../documentation/templates/bolt_project_reference.md.erb', __dir__)
      @opts    = Bolt::Config::OPTIONS.slice(*Bolt::Config::PROJECT_OPTIONS)

      # Move sub-options for 'log' option up one level, as they're nested under
      # 'console' and filepath
      @opts['log'][:properties] = @opts['log'][:additionalProperties][:properties]

      # Remove 'notice' log level. This is soft-deprecated and shouldn't appear
      # in documentation.
      @opts['log'][:properties]['level'][:enum].delete('notice')

      # Stringify data types
      @opts.transform_values! { |data| stringify_types(data) }

      # Generate YAML file examples
      @yaml = generate_yaml_file(@opts)

      renderer = ERB.new(File.read(template), trim_mode: '-')
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

      renderer = ERB.new(File.read(template), trim_mode: '-')
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

def format_type(type)
  type.gsub('Boltlib::', '')
end

def make_signature(function_name, params, return_type)
  params.map! { |param| param == '&block' ? param : "$#{param}" }
  "#{function_name}(#{params.join(', ')}) => #{return_type}"
end
