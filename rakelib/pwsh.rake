# frozen_string_literal: true

require 'erb'
require 'fileutils'

namespace :pwsh do
  desc "Generate the PowerShell module structure and supporting files"
  task generate_module: :generate_powershell_cmdlets do
    dest = File.expand_path(File.join(__dir__, '..', 'pwsh_module', 'PuppetBolt', 'en-US'))
    FileUtils.mkdir_p(dest) unless File.exist?(dest)

    begin
      source = File.expand_path(File.join(__dir__, '..', 'guides'))
      files  = Dir.children(source).sort.map { |f| File.join(source, f) }
      files.each_with_object({}) do |file, _guides|
        next if file !~ /\.(yaml|yml)\z/
        info = Bolt::Util.read_yaml_hash(file, 'guide')

        # Make sure both topic and guide keys are defined
        unless (%w[topic guide] - info.keys).empty?
          raise "Guide file #{file} must have a 'topic' key and 'guide' key, but has #{info.keys} keys."
        end

        txt = +"#{info['topic']}\n"
        txt << info['guide'].gsub(/^/, '  ')

        if info['documentation']
          txt << "\nDocumentation\n"
          txt << info['documentation'].join("\n").gsub(/^/, '  ')
        end

        File.write(File.join(dest, "about_bolt_#{info['topic']}.help.txt"), txt)
      end
    rescue SystemCallError => e
      raise Bolt::FileError.new("#{e.message}: unable to load guides directory", source)
    end

    # pwsh_module.psm1 ==> PuppetBolt.psm1
    content = File.read('pwsh_module/pwsh_bolt_internal.ps1') +
              File.read('pwsh_module/pwsh_bolt.psm1.erb')
    pwsh_module = ERB.new(content, trim_mode: '-')
    File.write('pwsh_module/PuppetBolt/PuppetBolt.psm1', pwsh_module.result)

    # pwsh_module.psd1 ==> PuppetBolt.psd1
    manifest = ERB.new(File.read('pwsh_module/pwsh_bolt.psd1.erb'), trim_mode: '-')
    File.write('pwsh_module/PuppetBolt/PuppetBolt.psd1', manifest.result)

    tests = ERB.new(File.read('pwsh_module/pwsh_bolt.tests.ps1.erb'), trim_mode: '-')
    File.write("pwsh_module/autogenerated.tests.ps1", tests.result)
  end

  desc "Generate the PowerShell module content from Bolt's command line options"
  task :generate_powershell_cmdlets do
    require 'bolt/cli'

    # https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands?view=powershell-7
    @pwsh_verbs = {
      'add'        => 'Add',
      'apply'      => 'Invoke',
      'convert'    => 'Convert',
      'createkeys' => 'New',
      'encrypt'    => 'Protect',
      'decrypt'    => 'Unprotect',
      'download'   => 'Receive',
      'init'       => 'New',
      'install'    => 'Install',
      'lookup'     => 'Invoke',
      'migrate'    => 'Update',
      'new'        => 'New',
      'run'        => 'Invoke',
      'show'       => 'Get',
      'upload'     => 'Send' # deploy? publish?
    }

    @hardcoded_cmdlets = {
      'secret:createkeys' => {
        'verb' => 'New',
        'noun' => 'BoltSecretKey'
      },
      'puppetfile:show-modules' => {
        'verb' => 'Get',
        'noun' => 'BoltPuppetfileModules'
      },
      'puppetfile:generate-types' => {
        'verb' => 'Register',
        'noun' => 'BoltPuppetfileTypes'
      },
      'module:generate-types' => {
        'verb' => 'Register',
        'noun' => 'BoltModuleTypes'
      }
    }

    parser = Bolt::BoltOptionParser.new({})

    @commands = []
    @mapped_options = {}

    Bolt::CLI::COMMANDS.each do |subcommand, actions|
      # The 'bolt guide' command is handled by PowerShell's help system, so
      # don't create a cmdlet for it.
      next if %w[guide].include?(subcommand)

      actions << nil if actions.empty?
      actions.each do |action|
        help_text = parser.get_help_text(subcommand, action)
        matches = help_text[:banner].match(/Usage(?<usage>.+?)Description(?<desc>.+?)(Documentation|Examples|\z)/m)
        action.chomp unless action.nil?

        if action.nil? && %w[apply lookup].include?(subcommand)
          cmdlet_verb = 'Invoke'
          cmdlet_noun = "Bolt#{subcommand.capitalize}"
        elsif @hardcoded_cmdlets["#{subcommand}:#{action}"]
          cmdlet_verb = @hardcoded_cmdlets["#{subcommand}:#{action}"]['verb']
          cmdlet_noun = @hardcoded_cmdlets["#{subcommand}:#{action}"]['noun']
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
          description:  matches[:desc].strip.delete("\t\r\n").gsub(/\s+/, ' '),
          syntax:       matches[:usage].strip
        }

        @pwsh_command[:options] = []

        case subcommand
        when 'apply'
          # bolt apply [manifest.pp] [options]
          # Cannot use bolt apply manifest.pp with --execute
          @pwsh_command[:options] << {
            name:                       'Manifest',
            ruby_short:                 'mf',
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
            name:                       'Command',
            ruby_short:                 'cm',
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
          script_param_mandatory = (@pwsh_command[:verb] != 'Get')
          @pwsh_command[:options] << {
            name:                       'Script',
            ruby_short:                 's',
            help_msg:                   "The script to #{action}",
            type:                       'string',
            switch:                     false,
            mandatory:                  script_param_mandatory,
            position:                   0,
            ruby_arg:                   'bare',
            validate_not_null_or_empty: true
          }
          unless @pwsh_command[:verb] == 'Get'
            @pwsh_command[:options] << {
              name:                           'Arguments',
              ruby_short:                     'a',
              help_msg:                       'The arguments to the script',
              type:                           'string[]',
              switch:                         false,
              mandatory:                      false,
              position:                       1,
              ruby_arg:                       'bare',
              value_from_remaining_arguments: true
            }
          end
        when 'task'
          # bolt task show|run <task> [parameters] [options]
          task_param_mandatory = (@pwsh_command[:verb] != 'Get')
          @pwsh_command[:options] << {
            name:                       'Name',
            ruby_short:                 'n',
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
          # bolt plan new <plan> [options]
          plan_param_mandatory = (@pwsh_command[:verb] != 'Get')
          @pwsh_command[:options] << {
            name:                       'Name',
            ruby_short:                 'n',
            help_msg:                   "The plan to #{action == 'new' ? 'create' : action}",
            type:                       'string',
            switch:                     false,
            mandatory:                  plan_param_mandatory,
            position:                   0,
            ruby_arg:                   'bare',
            validate_not_null_or_empty: true
          }
        when 'file'
          # bolt file download|upload <src> <dest> [options]
          @pwsh_command[:options] << {
            name:                       'Source',
            ruby_short:                 's',
            help_msg:                   "The source file or directory to #{action}",
            type:                       'string',
            switch:                     false,
            mandatory:                  true,
            position:                   0,
            ruby_arg:                   'bare',
            validate_not_null_or_empty: true
          }
          @pwsh_command[:options] << {
            name:                       'Destination',
            ruby_short:                 'd',
            type:                       'string',
            switch:                     false,
            mandatory:                  true,
            position:                   1,
            help_msg:                   "The destination to #{action} to",
            ruby_arg:                   'bare',
            validate_not_null_or_empty: true
          }
        when 'secret'
          # bolt secret encrypt <plaintext> [options]
          # bolt secret decrypt <ciphertext> [options]
          # bolt secret createkeys
          if @pwsh_command[:verb] != 'New'
            @pwsh_command[:options] << {
              name:                       'Text',
              ruby_short:                 't',
              help_msg:                   "The text to #{action}",
              type:                       'string',
              switch:                     false,
              mandatory:                  true,
              position:                   0,
              ruby_arg:                   'bare',
              validate_not_null_or_empty: true
            }
          end
        when 'project'
          # bolt project init [name] [options]
          # bolt project migrate
          if @pwsh_command[:verb] == 'New'
            @pwsh_command[:options] << {
              name:                       'Name',
              ruby_short:                 'n',
              help_msg:                   'The name of the Bolt project to create',
              mandatory:                  false,
              type:                       'string',
              switch:                     false,
              position:                   0,
              ruby_arg:                   'bare',
              validate_not_null_or_empty: true
            }
          end
        when 'module'
          # bolt module install
          # bolt module add [module]
          case @pwsh_command[:verb]
          when 'Add'
            @pwsh_command[:options] << {
              name:                       'Module',
              ruby_short:                 'md',
              help_msg:                   'The name of the module to add to the Bolt project',
              mandatory:                  true,
              type:                       'string',
              switch:                     false,
              position:                   0,
              ruby_arg:                   'bare',
              validate_not_null_or_empty: true
            }
          # bolt module show
          when 'Get'
            @pwsh_command[:options] << {
              name:                       'Name',
              ruby_short:                 'n',
              help_msg:                   "The module to show",
              type:                       'string',
              switch:                     false,
              mandatory:                  false,
              position:                   0,
              ruby_arg:                   'bare',
              validate_not_null_or_empty: true
            }
          end
        when 'lookup'
          # bolt lookup <key> [options]
          @pwsh_command[:options] << {
            name:                       'Key',
            ruby_short:                 'k',
            parameter_set:              'key',
            help_msg:                   'The key to look up',
            type:                       'string',
            switch:                     false,
            mandatory:                  true,
            position:                   0,
            ruby_arg:                   'bare',
            validate_not_null_or_empty: true
          }
        when 'policy'
          case @pwsh_command[:verb]
          # bolt policy apply <policy>
          when 'Invoke'
            @pwsh_command[:options] << {
              name:                       'Name',
              ruby_short:                 'n',
              help_msg:                   "The policy or policies to apply",
              type:                       'string',
              switch:                     false,
              mandatory:                  true,
              position:                   0,
              ruby_arg:                   'bare',
              validate_not_null_or_empty: true
            }
          # bolt policy new <policy>
          when 'New'
            @pwsh_command[:options] << {
              name:                       'Name',
              ruby_short:                 'n',
              help_msg:                   "The policy to create",
              type:                       'string',
              switch:                     false,
              mandatory:                  true,
              position:                   0,
              ruby_arg:                   'bare',
              validate_not_null_or_empty: true
            }
          end
        end

        # verbose is a commonparameter and is already present in the
        # pwsh cmdlets, so it is omitted here to prevent it from being
        # added twice
        help_text[:flags].reject { |o| o =~ /verbose|help|version/ }.map do |option|
          ruby_param = parser.top.long[option]
          pwsh_name = option.split("-").map(&:capitalize).join
          case pwsh_name
          when 'Tty'
            pwsh_name.upcase!
          end

          pwsh_param = {
            name:       pwsh_name,
            type:       'string',
            switch:     false,
            mandatory:  false,
            help_msg:   ruby_param.desc.join("\n  "),
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
          case pwsh_name.downcase
          when 'user', 'password', 'privatekey', 'concurrency',
            'compileconcurrency', 'connecttimeout', 'modulepath', 'targets',
            'query'
            pwsh_param[:validate_not_null_or_empty] = true
          when 'transport'
            pwsh_param[:validate_set] = Bolt::Config::Options::TRANSPORT_CONFIG.keys
          when 'loglevel'
            pwsh_param[:validate_set] = %w[trace debug info notice warn error fatal]
          when 'filter'
            pwsh_param[:validate_pattern] = '^[a-z0-9_:]+$'
          when 'rerun'
            pwsh_param[:validate_not_null_or_empty] = true
            pwsh_param[:validate_set] = %w[all failure success]
          when 'execute'
            pwsh_param[:parameter_set] = 'execute'
            pwsh_param[:mandatory] = true
            pwsh_param[:position] = 0
          when 'params'
            pwsh_param[:mandatory] = false
            pwsh_param[:position] = 1
            pwsh_param[:type] = nil
            pwsh_param[:value_from_remaining_arguments] = true
          when 'modules'
            pwsh_param[:type] = nil
          when 'format'
            pwsh_param[:validate_set] = %w[human json rainbow]
          end

          @pwsh_command[:options] << pwsh_param
        end

        # we add verbose back in when building the command to send to
        # bolt, so add it back to the global mapping here
        # this allows us to not have any filtering logic inside the erb
        @mapped_options['Verbose'] = 'verbose'

        # maintain a global list of pwsh parameter => ruby parameter
        # for the powershell erb file
        @pwsh_command[:options].map { |option| @mapped_options[option[:name]] = option[:ruby_orig] }

        @commands << @pwsh_command
      end
    end
  end
end
