# frozen_string_literal: true

# Note this file includes very few 'requires' because it expects to be used from the CLI.

require 'optparse'
require 'bolt/command/options'

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
          banner: BANNER['apply'] }
      when 'command'
        { flags: ACTION_OPTS,
          banner: BANNER['command'] }
      when 'file'
        { flags: ACTION_OPTS + %w[tmpdir],
          banner: BANNER['file'] }
      when 'inventory'
        { flags: OPTIONS[:inventory] + OPTIONS[:global] + %w[format inventoryfile boltdir configfile],
          banner: BANNER['inventory'] }
      when 'plan'
        case action
        when 'convert'
          { flags: OPTIONS[:global] + OPTIONS[:global_config_setters],
            banner: BANNER['plan convert'] }
        when 'show'
          { flags: OPTIONS[:global] + OPTIONS[:global_config_setters],
            banner: BANNER['plan show'] }
        when 'run'
          { flags: ACTION_OPTS + %w[params compile-concurrency tmpdir],
            banner: BANNER['plan run'] }
        else
          { flags: ACTION_OPTS + %w[params compile-concurrency tmpdir],
            banner: BANNER['plan'] }
        end
      when 'puppetfile'
        case action
        when 'install'
          { flags: OPTIONS[:global] + OPTIONS[:global_config_setters],
            banner: BANNER['puppetfile install'] }
        when 'show-modules'
          { flags: OPTIONS[:global] + OPTIONS[:global_config_setters],
            banner: BANNER['puppetfile show-modules'] }
        else
          { flags: OPTIONS[:global] + OPTIONS[:global_config_setters],
            banner: BANNER['puppetfile'] }
        end
      when 'script'
        { flags: ACTION_OPTS + %w[tmpdir],
          banner: BANNER['script'] }
      when 'secret'
        { flags: OPTIONS[:global] + OPTIONS[:global_config_setters],
          banner: BANNER['secret'] }
      when 'task'
        case action
        when 'show'
          { flags: OPTIONS[:global] + OPTIONS[:global_config_setters],
            banner: BANNER['task show'] }
        when 'run'
          { flags: ACTION_OPTS + %w[params tmpdir],
            banner: BANNER['task run'] }
        else
          { flags: ACTION_OPTS + %w[params tmpdir],
            banner: BANNER['task'] }
        end
      else
        { flags: OPTIONS[:global],
          banner: BANNER['default'] }
      end
    end

    def initialize(options)
      super()

      @options = options

      separator "\nOptions:"
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

      separator "\nInventory:"
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
             "List of directories containing modules, separated by '#{File::PATH_SEPARATOR}'",
             'Directories are case-sensitive') do |modulepath|
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
