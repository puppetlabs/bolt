# frozen_string_literal: true

# Note this file includes very few 'requires' because it expects to be used from the CLI.

require 'optparse'

module Bolt
  class BoltOptionParser < OptionParser
    OPTIONS = { inventory: %w[nodes targets query rerun description],
                authentication: %w[user password private-key host-key-check ssl ssl-verify],
                escalation: %w[run-as sudo-password],
                run_context: %w[concurrency inventoryfile save-rerun],
                global_config_setters: %w[modulepath boltdir configfile],
                transports: %w[transport connect-timeout tty],
                display: %w[format color verbose trace],
                global: %w[help version debug] }.freeze

    ACTION_OPTS = OPTIONS.values.flatten.freeze

    def get_help_text(subcommand, action = nil)
      case subcommand
      when 'apply'
        { flags: ACTION_OPTS + %w[noop execute compile-concurrency],
          banner: APPLY_HELP }
      when 'command'
        { flags: ACTION_OPTS,
          banner: COMMAND_HELP }
      when 'file'
        { flags: ACTION_OPTS + %w[tmpdir],
          banner: FILE_HELP }
      when 'plan'
        case action
        when 'convert'
          { flags: OPTIONS[:global] + OPTIONS[:global_config_setters],
            banner: PLAN_CONVERT_HELP }
        when 'show'
          { flags: OPTIONS[:global] + OPTIONS[:global_config_setters],
            banner: PLAN_SHOW_HELP }
        when 'run'
          { flags: ACTION_OPTS + %w[params compile-concurrency tmpdir],
            banner: PLAN_RUN_HELP }
        else
          { flags: ACTION_OPTS + %w[params compile-concurrency tmpdir],
            banner: PLAN_HELP }
        end
      when 'puppetfile'
        case action
        when 'install'
          { flags: OPTIONS[:global] + OPTIONS[:global_config_setters],
            banner: PUPPETFILE_INSTALL_HELP }
        when 'show-modules'
          { flags: OPTIONS[:global] + OPTIONS[:global_config_setters],
            banner: PUPPETFILE_SHOWMODULES_HELP }
        else
          { flags: OPTIONS[:global] + OPTIONS[:global_config_setters],
            banner: PUPPETFILE_HELP }
        end
      when 'script'
        { flags: ACTION_OPTS + %w[tmpdir],
          banner: SCRIPT_HELP }
      when 'task'
        case action
        when 'show'
          { flags: OPTIONS[:global] + OPTIONS[:global_config_setters],
            banner: TASK_SHOW_HELP }
        when 'run'
          { flags: ACTION_OPTS + %w[params tmpdir],
            banner: TASK_RUN_HELP }
        else
          { flags: ACTION_OPTS + %w[params tmpdir],
            banner: TASK_HELP }
        end
      else
        { flags: OPTIONS[:global],
          banner: BANNER }
      end
    end

    def self.examples(cmd, desc)
      <<-EXAMP
#{desc} a Windows host via WinRM, providing for the password
  bolt #{cmd} -n winrm://winhost -u Administrator -p
#{desc} the local machine, a Linux host via SSH, and hosts from a group specified in an inventory file
  bolt #{cmd} -n localhost,nixhost,node_group
#{desc} Windows hosts queried from PuppetDB via WinRM as a domain user, prompting for the password
  bolt #{cmd} -q 'inventory[certname] { facts.os.family = "windows" }' --transport winrm -u 'domain\\Administrator' -p
EXAMP
    end

    BANNER = <<-HELP
Usage: bolt <subcommand> <action>

Available subcommands:
  bolt command run <command>       Run a command remotely
  bolt file upload <src> <dest>    Upload a local file or directory
  bolt script run <script>         Upload a local script and run it remotely
  bolt task show                   Show list of available tasks
  bolt task show <task>            Show documentation for task
  bolt task run <task> [params]    Run a Puppet task
  bolt plan convert <plan_path>    Convert a YAML plan to a Puppet plan
  bolt plan show                   Show list of available plans
  bolt plan show <plan>            Show details for plan
  bolt plan run <plan> [params]    Run a Puppet task plan
  bolt apply <manifest>            Apply Puppet manifest code
  bolt puppetfile install          Install modules from a Puppetfile into a Boltdir
  bolt puppetfile show-modules     List modules available to Bolt

Run `bolt <subcommand> --help` to view specific examples.

Available options are:
    HELP

    TASK_HELP = <<-HELP
Usage: bolt task <action> <task> [parameters]

Available actions are:
  show                             Show list of available tasks
  show <task>                      Show documentation for task
  run <task>                       Run a Puppet task

Parameters are of the form <parameter>=<value>.

#{examples('task run facts', 'run facter on')}
Available options are:
    HELP

    TASK_SHOW_HELP = <<-HELP
Usage: bolt task show <task>

Available actions are:
  show                             Show list of available tasks
  show <task>                      Show documentation for task

Available options are:
    HELP

    TASK_RUN_HELP = <<-HELP
Usage: bolt task run <task> [parameters]

Parameters are of the form <parameter>=<value>.

#{examples('task run facts', 'run facter on')}
Available options are:
    HELP

    COMMAND_HELP = <<-HELP
Usage: bolt command <action> <command>

Available actions are:
  run                              Run a command remotely

#{examples('command run hostname', 'run hostname on')}
Available options are:
    HELP

    SCRIPT_HELP = <<-HELP
Usage: bolt script <action> <script> [[arg1] ... [argN]]

Available actions are:
  run                              Upload a local script and run it remotely

#{examples('script run my_script.ps1 some args', 'run a script on')}
Available options are:
    HELP

    PLAN_HELP = <<-HELP
Usage: bolt plan <action> <plan> [parameters]

Available actions are:
  convert <plan_path>              Convert a YAML plan to a Puppet plan
  show                             Show list of available plans
  show <plan>                      Show details for plan
  run                              Run a Puppet task plan

Parameters are of the form <parameter>=<value>.

#{examples('plan run canary command=hostname', 'run the canary plan on')}
Available options are:
    HELP

    PLAN_CONVERT_HELP = <<-HELP
Usage: bolt plan convert <plan_path>

Available options are:
    HELP

    PLAN_SHOW_HELP = <<-HELP
Usage: bolt plan show <plan>

Available actions are:
  show                             Show list of available plans
  show <plan>                      Show details for plan

Available options are:
    HELP

    PLAN_RUN_HELP = <<-HELP
Usage: bolt plan run <plan> [parameters]

Parameters are of the form <parameter>=<value>.

#{examples('plan run canary command=hostname', 'run the canary plan on')}
Available options are:
    HELP

    FILE_HELP = <<-HELP
Usage: bolt file <action>

Available actions are:
  upload <src> <dest>              Upload local file or directory <src> to <dest> on each node

#{examples('file upload /tmp/source /etc/profile.d/login.sh', 'upload a file to')}
Available options are:
    HELP

    PUPPETFILE_HELP = <<-HELP
Usage: bolt puppetfile <action>

Available actions are:
  install                          Install modules from a Puppetfile into a Boltdir
  show-modules                     List modules available to Bolt

Install modules into the local Boltdir
  bolt puppetfile install

Available options are:
    HELP

    PUPPETFILE_INSTALL_HELP = <<-HELP
Usage: bolt puppetfile install

Install modules into the local Boltdir
  bolt puppetfile install

Available options are:
    HELP

    PUPPETFILE_SHOWMODULES_HELP = <<-HELP
Usage: bolt puppetfile show-modules

Available options are:
    HELP

    APPLY_HELP = <<-HELP
Usage: bolt apply <manifest.pp>

#{examples('apply site.pp', 'apply a manifest on')}
  bolt apply site.pp --nodes foo.example.com,bar.example.com

Available options are:
    HELP

    def initialize(options)
      super()

      @options = options

      define('-n', '--nodes NODES',
             'Alias for --targets') do |nodes|
        @options [:nodes] ||= []
        @options[:nodes] << get_arg_input(nodes)
      end
      define('-t', '--targets TARGETS',
             'Identifies the targets of command.',
             'Enter a comma-separated list of target URIs or group names.',
             "Or read a target list from an input file '@<file>' or stdin '-'.",
             'Example: --targets localhost,node_group,ssh://nix.com:23,winrm://windows.puppet.com',
             'URI format is [protocol://]host[:port]',
             "SSH is the default protocol; may be #{TRANSPORTS.keys.join(', ')}",
             'For Windows targets, specify the winrm:// protocol if it has not be configured',
             'For SSH, port defaults to `22`',
             'For WinRM, port defaults to `5985` or `5986` based on the --[no-]ssl setting') do |targets|
        @options[:targets] ||= []
        @options[:targets] << get_arg_input(targets)
      end
      define('-q', '--query QUERY', 'Query PuppetDB to determine the targets') do |query|
        @options[:query] = query
      end
      define('--rerun FILTER', 'Retry on nodes from the last run',
             "'all' all nodes that were part of the last run.",
             "'failure' nodes that failed in the last run.",
             "'success' nodes that succeeded in the last run.") do |rerun|
        @options[:rerun] = rerun
      end
      define('--noop', 'Execute a task that supports it in noop mode') do |_|
        @options[:noop] = true
      end
      define('--description DESCRIPTION',
             'Description to use for the job') do |description|
        @options[:description] = description
      end
      define('--params PARAMETERS',
             "Parameters to a task or plan as json, a json file '@<file>', or on stdin '-'") do |params|
        @options[:task_options] = parse_params(params)
      end
      define('-e', '--execute CODE',
             "Puppet manifest code to apply to the targets") do |code|
        @options[:code] = code
      end

      separator "\nAuthentication:"
      define('-u', '--user USER', 'User to authenticate as') do |user|
        @options[:user] = user
      end
      define('-p', '--password [PASSWORD]',
             'Password to authenticate with. Omit the value to prompt for the password.') do |password|
        if password.nil?
          STDOUT.print "Please enter your password: "
          @options[:password] = STDIN.noecho(&:gets).chomp
          STDOUT.puts
        else
          @options[:password] = password
        end
      end
      define('--private-key KEY', 'Private ssh key to authenticate with') do |key|
        @options[:'private-key'] = key
      end
      define('--[no-]host-key-check', 'Check host keys with SSH') do |host_key_check|
        @options[:'host-key-check'] = host_key_check
      end
      define('--[no-]ssl', 'Use SSL with WinRM') do |ssl|
        @options[:ssl] = ssl
      end
      define('--[no-]ssl-verify', 'Verify remote host SSL certificate with WinRM') do |ssl_verify|
        @options[:'ssl-verify'] = ssl_verify
      end

      separator "\nEscalation:"
      define('--run-as USER', 'User to run as using privilege escalation') do |user|
        @options[:'run-as'] = user
      end
      define('--sudo-password [PASSWORD]',
             'Password for privilege escalation. Omit the value to prompt for the password.') do |password|
        if password.nil?
          STDOUT.print "Please enter your privilege escalation password: "
          @options[:'sudo-password'] = STDIN.noecho(&:gets).chomp
          STDOUT.puts
        else
          @options[:'sudo-password'] = password
        end
      end

      separator "\nRun context:"
      define('-c', '--concurrency CONCURRENCY', Integer,
             'Maximum number of simultaneous connections (default: 100)') do |concurrency|
        @options[:concurrency] = concurrency
      end
      define('--compile-concurrency CONCURRENCY', Integer,
             'Maximum number of simultaneous manifest block compiles (default: number of cores)') do |concurrency|
        @options[:'compile-concurrency'] = concurrency
      end
      define('-m', '--modulepath MODULES',
             "List of directories containing modules, separated by '#{File::PATH_SEPARATOR}'") do |modulepath|
        # When specified from the CLI, modulepath entries are relative to pwd
        @options[:modulepath] = modulepath.split(File::PATH_SEPARATOR).map do |moduledir|
          File.expand_path(moduledir)
        end
      end
      define('--boltdir FILEPATH',
             'Specify what Boltdir to load config from (default: autodiscovered from current working dir)') do |path|
        @options[:boltdir] = path
      end
      define('--configfile FILEPATH',
             'Specify where to load config from (default: ~/.puppetlabs/bolt/bolt.yaml)') do |path|
        @options[:configfile] = path
      end
      define('-i', '--inventoryfile FILEPATH',
             'Specify where to load inventory from (default: ~/.puppetlabs/bolt/inventory.yaml)') do |path|
        if ENV.include?(Bolt::Inventory::ENVIRONMENT_VAR)
          raise Bolt::CLIError, "Cannot pass inventory file when #{Bolt::Inventory::ENVIRONMENT_VAR} is set"
        end
        @options[:inventoryfile] = File.expand_path(path)
      end
      define('--[no-]save-rerun', 'Whether to update the rerun file after this command.') do |save|
        @options[:'save-rerun'] = save
      end

      separator "\nTransports:"
      define('--transport TRANSPORT', TRANSPORTS.keys.map(&:to_s),
             "Specify a default transport: #{TRANSPORTS.keys.join(', ')}") do |t|
        @options[:transport] = t
      end
      define('--connect-timeout TIMEOUT', Integer, 'Connection timeout (defaults vary)') do |timeout|
        @options[:'connect-timeout'] = timeout
      end
      define('--[no-]tty', 'Request a pseudo TTY on nodes that support it') do |tty|
        @options[:tty] = tty
      end
      define('--tmpdir DIR', 'The directory to upload and execute temporary files on the target') do |tmpdir|
        @options[:tmpdir] = tmpdir
      end

      separator "\nDisplay:"
      define('--format FORMAT', 'Output format to use: human or json') do |format|
        @options[:format] = format
      end
      define('--[no-]color', 'Whether to show output in color') do |color|
        @options[:color] = color
      end
      define('-v', '--[no-]verbose', 'Display verbose logging') do |value|
        @options[:verbose] = value
      end
      define('--trace', 'Display error stack traces') do |_|
        @options[:trace] = true
      end

      separator "\nGlobal:"
      define('-h', '--help', 'Display help') do |_|
        @options[:help] = true
      end
      define('--version', 'Display the version') do |_|
        puts Bolt::VERSION
        raise Bolt::CLIExit
      end
      define('--debug', 'Display debug logging') do |_|
        @options[:debug] = true
      end
    end

    def remove_excluded_opts(option_list)
      # Remove any options that are not available for the specified subcommand
      top.list.delete_if do |opt|
        opt.respond_to?(:switch_name) && !option_list.include?(opt.switch_name)
      end
      # Remove any separators if all options of that type have been removed
      top.list.delete_if do |opt|
        i = top.list.index(opt)
        opt.is_a?(String) && top.list[i + 1].is_a?(String)
      end
    end

    def update
      help_text = get_help_text(@options[:subcommand], @options[:action])
      # Update the banner according to the subcommand
      self.banner = help_text[:banner]
      # Builds the option list for the specified subcommand and removes all excluded
      # options from the help text
      remove_excluded_opts(help_text[:flags])
    end

    def parse_params(params)
      json = get_arg_input(params)
      JSON.parse(json)
    rescue JSON::ParserError => e
      raise Bolt::CLIError, "Unable to parse --params value as JSON: #{e}"
    end

    def get_arg_input(value)
      if value.start_with?('@')
        file = value.sub(/^@/, '')
        read_arg_file(file)
      elsif value == '-'
        STDIN.read
      else
        value
      end
    end

    def read_arg_file(file)
      File.read(File.expand_path(file))
    rescue StandardError => e
      raise Bolt::FileError.new("Error attempting to read #{file}: #{e}", file)
    end
  end
end
