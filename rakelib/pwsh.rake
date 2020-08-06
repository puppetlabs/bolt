# frozen_string_literal: true

require 'bolt/cli'
require 'erb'

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
      'upload'     => 'Send', # deploy? publish?
      'download'   => 'Receive',
      'new'        => 'New'
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
    @mapped_options = {}

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
          @pwsh_command[:options] << {
            name:                       'Script',
            ruby_short:                 's',
            help_msg:                   'The script to execute',
            type:                       'string',
            switch:                     false,
            mandatory:                  true,
            position:                   0,
            ruby_arg:                   'bare',
            validate_not_null_or_empty: true
          }
          @pwsh_command[:options] << {
            name:       'Arguments',
            ruby_short: 'a',
            help_msg:   'The arguments to the script',
            type:       'string',
            switch:     false,
            mandatory:  false,
            position:   1,
            ruby_arg:   'bare'
          }
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
          @pwsh_command[:options] << {
            name:                       'Name',
            ruby_short:                 'n',
            help_msg:                   "The plan to #{action == 'new' ? 'create' : action}",
            type:                       'string',
            switch:                     false,
            mandatory:                  false,
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
        when 'project'
          # bolt project init [directory] [options]
          @pwsh_command[:options] << {
            name:                       'Directory',
            ruby_short:                 'd',
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
        help_text[:flags].reject { |o| o =~ /verbose|debug|help|version/ }.map do |option|
          ruby_param = parser.top.long[option]
          pwsh_name = option.split("-").map(&:capitalize).join('')
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
          # Only one of --configfile or --boltdir can be used
          case pwsh_name.downcase
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

        # maintain a global list of pwsh parameter => ruby parameter
        # for the powershell erb file
        @pwsh_command[:options].map { |option| @mapped_options[option[:name]] = option[:ruby_orig] }

        @commands << @pwsh_command
      end
    end

    # pwsh_module.psm1 ==> PuppetBolt.psm1
    content = File.read('pwsh_module/pwsh_bolt_internal.ps1') +
              File.read('pwsh_module/pwsh_bolt.psm1.erb')
    pwsh_module = ERB.new(content, nil, '-')
    File.write('pwsh_module/PuppetBolt.psm1', pwsh_module.result)

    # pwsh_module.psd1 ==> PuppetBolt.psd1
    manifest = ERB.new(File.read('pwsh_module/pwsh_bolt.psd1.erb'), nil, '-')
    File.write('pwsh_module/PuppetBolt.psd1', manifest.result)

    tests = ERB.new(File.read('pwsh_module/pwsh_bolt.tests.ps1.erb'), nil, '-')
    File.write("pwsh_module/autogenerated.tests.ps1", tests.result)

    docs = ERB.new(File.read('documentation/templates/bolt_pwsh_reference.md.erb'), nil, '-')
    File.write("documentation/bolt_pwsh_reference.md", docs.result)
  end
end
