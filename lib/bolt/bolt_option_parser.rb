# frozen_string_literal: true

require 'optparse'

module Bolt
  class BoltOptionParser < OptionParser
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
Usage: bolt <subcommand> <action> [options]

Available subcommands:
  bolt command run <command>       Run a command remotely
  bolt file upload <src> <dest>    Upload a local file
  bolt script run <script>         Upload a local script and run it remotely
  bolt task show                   Show list of available tasks
  bolt task show <task>            Show documentation for task
  bolt task run <task> [params]    Run a Puppet task
  bolt plan show                   Show list of available plans
  bolt plan show <plan>            Show details for plan
  bolt plan run <plan> [params]    Run a Puppet task plan
  bolt puppetfile install          Install modules from a Puppetfile into a Boltdir

Run `bolt <subcommand> --help` to view specific examples.

where [options] are:
    HELP

    TASK_HELP = <<-HELP
Usage: bolt task <action> <task> [options] [parameters]

Available actions are:
  show                             Show list of available tasks
  show <task>                      Show documentation for task
  run                              Run a Puppet task

Parameters are of the form <parameter>=<value>.

#{examples('task run facts', 'run facter on')}
Available options are:
    HELP

    COMMAND_HELP = <<-HELP
Usage: bolt command <action> <command> [options]

Available actions are:
  run                              Run a command remotely

#{examples('command run hostname', 'run hostname on')}
Available options are:
    HELP

    SCRIPT_HELP = <<-HELP
Usage: bolt script <action> <script> [[arg1] ... [argN]] [options]

Available actions are:
  run                              Upload a local script and run it remotely

#{examples('script run my_script.ps1 some args', 'run a script on')}
Available options are:
    HELP

    PLAN_HELP = <<-HELP
Usage: bolt plan <action> <plan> [options] [parameters]

Available actions are:
  show                             Show list of available plans
  show <plan>                      Show details for plan
  run                              Run a Puppet task plan

Parameters are of the form <parameter>=<value>.

#{examples('plan run canary command=hostname', 'run the canary plan on')}
Available options are:
    HELP

    FILE_HELP = <<-HELP
Usage: bolt file <action> [options]

Available actions are:
  upload <src> <dest>              Upload local file <src> to <dest> on each node

#{examples('file upload /tmp/source /etc/profile.d/login.sh', 'upload a file to')}
Available options are:
    HELP

    PUPPETFILE_HELP = <<-HELP
Usage: bolt puppetfile <action> [options]

Available actions are:
  install                          Install modules from a Puppetfile into a Boltdir

Install modules into the local Boltdir
  bolt puppetfile install

Available options are:
    HELP

    # A helper mixin for OptionParser::Switch instances which will allow
    # us to show/hide particular switch in the help message produced by
    # the OptionParser#help method on demand.
    module SwitchHider
      attr_accessor :hide

      def summarize(*args)
        return self if hide
        super
      end
    end

    def initialize(options)
      super()

      @options = options

      @nodes = define('-n', '--nodes NODES',
                      'Identifies the nodes to target.',
                      'Enter a comma-separated list of node URIs or group names.',
                      "Or read a node list from an input file '@<file>' or stdin '-'.",
                      'Example: --nodes localhost,node_group,ssh://nix.com:23,winrm://windows.puppet.com',
                      'URI format is [protocol://]host[:port]',
                      "SSH is the default protocol; may be #{TRANSPORTS.keys.join(', ')}",
                      'For Windows nodes, specify the winrm:// protocol if it has not be configured',
                      'For SSH, port defaults to `22`',
                      'For WinRM, port defaults to `5985` or `5986` based on the --[no-]ssl setting') do |nodes|
        @options[:nodes] << get_arg_input(nodes)
      end.extend(SwitchHider)
      @query = define('-q', '--query QUERY', 'Query PuppetDB to determine the targets') do |query|
        @options[:query] = query
      end.extend(SwitchHider)
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

      separator 'Authentication:'
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

      separator 'Escalation:'
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

      separator 'Run context:'
      define('-c', '--concurrency CONCURRENCY', Integer,
             'Maximum number of simultaneous connections (default: 100)') do |concurrency|
        @options[:concurrency] = concurrency
      end
      define('--compile-concurrency CONCURRENCY', Integer,
             'Maximum number of simultaneous manifest block compiles (default: number of cores)') do |concurrency|
        @options[:'compile-concurrency'] = concurrency
      end
      define('--modulepath MODULES',
             "List of directories containing modules, separated by '#{File::PATH_SEPARATOR}'") do |modulepath|
        @options[:modulepath] = modulepath.split(File::PATH_SEPARATOR)
      end
      define('--boltdir FILEPATH',
             'Specify what Boltdir to load config from (default: autodiscovered from current working dir)') do |path|
        @options[:boltdir] = path
      end
      define('--configfile FILEPATH',
             'Specify where to load config from (default: ~/.puppetlabs/bolt/bolt.yaml)') do |path|
        @options[:configfile] = path
      end
      define('--inventoryfile FILEPATH',
             'Specify where to load inventory from (default: ~/.puppetlabs/bolt/inventory.yaml)') do |path|
        if ENV.include?(Bolt::Inventory::ENVIRONMENT_VAR)
          raise Bolt::CLIError, "Cannot pass inventory file when #{Bolt::Inventory::ENVIRONMENT_VAR} is set"
        end
        @options[:inventoryfile] = path
      end

      separator 'Transports:'
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

      separator 'Display:'
      define('--format FORMAT', 'Output format to use: human or json') do |format|
        @options[:format] = format
      end
      define('--[no-]color', 'Whether to show output in color') do |color|
        @options[:color] = color
      end
      define('-h', '--help', 'Display help') do |_|
        @options[:help] = true
      end
      define('--verbose', 'Display verbose logging') do |_|
        @options[:verbose] = true
      end
      define('--debug', 'Display debug logging') do |_|
        @options[:debug] = true
      end
      define('--trace', 'Display error stack traces') do |_|
        @options[:trace] = true
      end
      define('--version', 'Display the version') do |_|
        puts Bolt::VERSION
        raise Bolt::CLIExit
      end

      update
    end

    def update
      # show the --nodes and --query switches by default
      @nodes.hide = @query.hide = false

      # Update the banner according to the subcommand
      self.banner = case @options[:subcommand]
                    when 'plan'
                      # don't show the --nodes and --query switches in the plan help
                      @nodes.hide = @query.hide = true
                      PLAN_HELP
                    when 'command'
                      COMMAND_HELP
                    when 'script'
                      SCRIPT_HELP
                    when 'task'
                      TASK_HELP
                    when 'file'
                      FILE_HELP
                    when 'puppetfile'
                      PUPPETFILE_HELP
                    else
                      BANNER
                    end
    end

    def parse_params(params)
      json = get_arg_input(params)
      JSON.parse(json)
    rescue JSON::ParserError => err
      raise Bolt::CLIError, "Unable to parse --params value as JSON: #{err}"
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
      File.read(file)
    rescue StandardError => err
      raise Bolt::FileError.new("Error attempting to read #{file}: #{err}", file)
    end
  end
end
