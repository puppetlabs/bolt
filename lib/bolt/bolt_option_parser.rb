# frozen_string_literal: true

# Note this file includes very few 'requires' because it expects to be used from the CLI.

require 'optparse'

module Bolt
  class BoltOptionParser < OptionParser
    OPTIONS = { inventory: %w[nodes targets query rerun description],
                authentication: %w[user password password-prompt private-key host-key-check ssl ssl-verify],
                escalation: %w[run-as sudo-password sudo-password-prompt sudo-executable],
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
        case action
        when 'run'
          { flags: ACTION_OPTS,
            banner: COMMAND_RUN_HELP }
        else
          { flags: OPTIONS[:global],
            banner: COMMAND_HELP }
        end
      when 'file'
        case action
        when 'upload'
          { flags: ACTION_OPTS + %w[tmpdir],
            banner: FILE_UPLOAD_HELP }
        else
          { flags: OPTIONS[:global],
            banner: FILE_HELP }
        end
      when 'inventory'
        case action
        when 'show'
          { flags: OPTIONS[:inventory] + OPTIONS[:global] + %w[format inventoryfile boltdir configfile detail],
            banner: INVENTORY_SHOW_HELP }
        else
          { flags: OPTIONS[:global],
            banner: INVENTORY_HELP }
        end
      when 'group'
        case action
        when 'show'
          { flags: OPTIONS[:global] + %w[format inventoryfile boltdir configfile],
            banner: GROUP_SHOW_HELP }
        else
          { flags: OPTIONS[:global],
            banner: GROUP_HELP }
        end
      when 'plan'
        case action
        when 'convert'
          { flags: OPTIONS[:global] + OPTIONS[:global_config_setters],
            banner: PLAN_CONVERT_HELP }
        when 'run'
          { flags: ACTION_OPTS + %w[params compile-concurrency tmpdir],
            banner: PLAN_RUN_HELP }
        when 'show'
          { flags: OPTIONS[:global] + OPTIONS[:global_config_setters] + %w[filter format],
            banner: PLAN_SHOW_HELP }
        else
          { flags: OPTIONS[:global],
            banner: PLAN_HELP }
        end
      when 'project'
        case action
        when 'init'
          { flags: OPTIONS[:global],
            banner: PROJECT_INIT_HELP }
        when 'migrate'
          { flags: OPTIONS[:global] + %w[inventoryfile boltdir configfile],
            banner: PROJECT_MIGRATE_HELP }
        else
          { flags: OPTIONS[:global],
            banner: PROJECT_HELP }
        end
      when 'puppetfile'
        case action
        when 'install'
          { flags: OPTIONS[:global] + OPTIONS[:global_config_setters],
            banner: PUPPETFILE_INSTALL_HELP }
        when 'show-modules'
          { flags: OPTIONS[:global] + OPTIONS[:global_config_setters],
            banner: PUPPETFILE_SHOWMODULES_HELP }
        when 'generate-types'
          { flags: OPTIONS[:global] + OPTIONS[:global_config_setters],
            banner: PUPPETFILE_GENERATETYPES_HELP }
        else
          { flags: OPTIONS[:global],
            banner: PUPPETFILE_HELP }
        end
      when 'script'
        case action
        when 'run'
          { flags: ACTION_OPTS + %w[tmpdir],
            banner: SCRIPT_RUN_HELP }
        else
          { flags: OPTIONS[:global],
            banner: SCRIPT_HELP }
        end
      when 'secret'
        case action
        when 'createkeys'
          { flags: OPTIONS[:global] + OPTIONS[:global_config_setters] + %w[plugin],
            banner: SECRET_CREATEKEYS_HELP }
        when 'decrypt'
          { flags: OPTIONS[:global] + OPTIONS[:global_config_setters] + %w[plugin],
            banner: SECRET_DECRYPT_HELP }
        when 'encrypt'
          { flags: OPTIONS[:global] + OPTIONS[:global_config_setters] + %w[plugin],
            banner: SECRET_ENCRYPT_HELP }
        else
          { flags: OPTIONS[:global],
            banner: SECRET_HELP }
        end
      when 'task'
        case action
        when 'run'
          { flags: ACTION_OPTS + %w[params tmpdir noop],
            banner: TASK_RUN_HELP }
        when 'show'
          { flags: OPTIONS[:global] + OPTIONS[:global_config_setters] + %w[filter format],
            banner: TASK_SHOW_HELP }
        else
          { flags: OPTIONS[:global],
            banner: TASK_HELP }
        end
      else
        { flags: OPTIONS[:global],
          banner: BANNER }
      end
    end

    BANNER = <<~HELP
      NAME
          bolt

      USAGE
          bolt <subcommand> [action] [options]

      DESCRIPTION
          Bolt is an orchestration tool that automates the manual work it takes to
          maintain your infrastructure.

      SUBCOMMANDS
          apply             Apply Puppet manifest code
          command           Run a command remotely
          file              Upload a local file or directory
          group             Show the list of groups in the inventory
          inventory         Show the list of targets an action would run on
          plan              Convert, show, and run Bolt plans
          project           Create and migrate Bolt projects
          puppetfile        Install and list modules and generate type references
          script            Upload a local script and run it remotely
          secret            Create encryption keys and encrypt and decrypt values
          task              Show and run Bolt tasks
    HELP

    APPLY_HELP = <<~HELP
      NAME
          apply

      USAGE
          bolt apply <manifest.pp> [options]

      DESCRIPTION
          Apply Puppet manifest code on the specified targets.

      EXAMPLES
          bolt apply manifest.pp --targets target1,target2
    HELP

    COMMAND_HELP = <<~HELP
      NAME
          command

      USAGE
          bolt command <action> [options]

      DESCRIPTION
          Run a command on the specified targets.

      ACTIONS
          run         Run a command on the specified targets.
    HELP

    COMMAND_RUN_HELP = <<~HELP
      NAME
          run

      USAGE
          bolt command run <command> [options]

      DESCRIPTION
          Run a command on the specified targets.

      EXAMPLES
          bolt command run 'uptime' -t target1,target2
    HELP

    FILE_HELP = <<~HELP
      NAME
          file

      USAGE
          bolt file <action> [options]

      DESCRIPTION
          Upload a local file or directory

      ACTIONS
          upload        Upload a local file or directory
    HELP

    FILE_UPLOAD_HELP = <<~HELP
      NAME
          upload

      USAGE
          bolt file upload <src> <dest> [options]

      DESCRIPTION
          Upload a local file or directory.

      EXAMPLES
          bolt file upload /tmp/source /etc/profile.d/login.sh -t target1
    HELP

    GROUP_HELP = <<~HELP
      NAME
          group

      USAGE
          bolt group <action> [options]

      DESCRIPTION
          Show the list of groups in the inventory.

      ACTIONS
          show          Show the list of groups in the inventory
    HELP

    GROUP_SHOW_HELP = <<~HELP
      NAME
          show

      USAGE
          bolt group show [options]

      DESCRIPTION
          Show the list of groups in the inventory.
    HELP

    INVENTORY_HELP = <<~HELP
      NAME
          inventory

      USAGE
          bolt inventory <action> [options]

      DESCRIPTION
          Show the list of targets an action would run on.

      ACTIONS
          show          Show the list of targets an action would run on
    HELP

    INVENTORY_SHOW_HELP = <<~HELP
      NAME
          show

      USAGE
          bolt inventory show [options]

      DESCRIPTION
          Show the list of targets an action would run on.
    HELP

    PLAN_HELP = <<~HELP
      NAME
          plan

      USAGE
          bolt plan <action> [parameters] [options]

      DESCRIPTION
          Convert, show, and run Bolt plans.

      ACTIONS
          convert       Convert a YAML plan to a Bolt plan
          run           Run a plan on the specified targets
          show          Show available plans and plan documentation
    HELP

    PLAN_CONVERT_HELP = <<~HELP
      NAME
          convert

      USAGE
          bolt plan convert <path> [options]

      DESCRIPTION
          Convert a YAML plan to a Bolt plan.

          Converting a YAML plan may result in a plan that is syntactically
          correct but has different behavior. Always verify a converted plan's
          functionality.

      EXAMPLES
          bolt plan convert path/to/plan/myplan.yaml
    HELP

    PLAN_RUN_HELP = <<~HELP
      NAME
          run

      USAGE
          bolt plan run <plan> [parameters] [options]

      DESCRIPTION
          Run a plan on the specified targets.

      EXAMPLES
          bolt plan run canary --targets target1,target2 command=hostname
    HELP

    PLAN_SHOW_HELP = <<~HELP
      NAME
          show

      USAGE
          bolt plan show [plan] [options]

      DESCRIPTION
          Show available plans and plan documentation.

          Omitting the name of a plan will display a list of plans available
          in the Bolt project.

          Providing the name of a plan will display detailed documentation for
          the plan, including a list of available parameters.

      EXAMPLES
          Display a list of available tasks
            bolt plan show
          Display documentation for the canary task
            bolt plan show aggregate::count
    HELP

    PROJECT_HELP = <<~HELP
      NAME
          project

      USAGE
          bolt project <action> [options]

      DESCRIPTION
          Create and migrate Bolt projects

      ACTIONS
          init              Create a new Bolt project
          migrate           Migrate a Bolt project to the latest version
    HELP

    PROJECT_INIT_HELP = <<~HELP
      NAME
          init

      USAGE
          bolt project init [directory] [options]

      DESCRIPTION
          Create a new Bolt project.

          Specify a directory to create a Bolt project in. Defaults to the
          curent working directory.

      EXAMPLES
          Create a new Bolt project in the current working directory.
            bolt project init
          Create a new Bolt project at a specified path.
            bolt project init ~/path/to/project
    HELP

    PROJECT_MIGRATE_HELP = <<~HELP
      NAME
          migrate

      USAGE
          bolt project migrate [options]

      DESCRIPTION
          Migrate a Bolt project to the latest version.

          Loads a Bolt project's inventory file and migrates it to the latest version. The
          inventory file is modified in place and will not preserve comments or formatting.
    HELP

    PUPPETFILE_HELP = <<~HELP
      NAME
          puppetfile

      USAGE
          bolt puppetfile <action> [options]

      DESCRIPTION
          Install and list modules and generate type references

      ACTIONS
          generate-types        Generate type references to register in plans
          install               Install modules from a Puppetfile into a Boltdir
          show-modules          List modules available to the Bolt project
    HELP

    PUPPETFILE_GENERATETYPES_HELP = <<~HELP
      NAME
          generate-types

      USAGE
          bolt puppetfile generate-types [options]

      DESCRIPTION
          Generate type references to register in plans.
    HELP

    PUPPETFILE_INSTALL_HELP = <<~HELP
      NAME
          install

      USAGE
          bolt puppetfile install [options]

      DESCRIPTION
          Install modules from a Puppetfile into a Boltdir
    HELP

    PUPPETFILE_SHOWMODULES_HELP = <<~HELP
      NAME
          show-modules

      USAGE
          bolt puppetfile show-modules [options]

      DESCRIPTION
          List modules available to the Bolt project.
    HELP

    SCRIPT_HELP = <<~HELP
      NAME
          script

      USAGE
          bolt script <action> [options]

      DESCRIPTION
          Run a script on the specified targets.

      ACTIONS
          run         Run a script on the specified targets.
    HELP

    SCRIPT_RUN_HELP = <<~HELP
      NAME
          run

      USAGE
          bolt script run <script> [arguments] [options]

      DESCRIPTION
          Run a script on the specified targets.

          Arguments passed to a script are passed literally and are not interpolated
          by the shell. Any arguments containing spaces or special characters should
          be quoted.

      EXAMPLES
          bolt script run myscript.sh 'echo hello' --targets target1,target2
    HELP

    SECRET_HELP = <<~HELP
      NAME
          secret

      USAGE
          bolt secret <action> [options]

      DESCRIPTION
          Create encryption keys and encrypt and decrypt values.

      ACTIONS
          createkeys           Create new encryption keys
          encrypt              Encrypt a value
          decrypt              Decrypt a value
    HELP

    SECRET_CREATEKEYS_HELP = <<~HELP
      NAME
          createkeys

      USAGE
          bolt secret createkeys [options]

      DESCRIPTION
          Create new encryption keys.
    HELP

    SECRET_DECRYPT_HELP = <<~HELP
      NAME
          decrypt

      USAGE
          bolt secret decrypt <ciphertext> [options]

      DESCRIPTION
          Decrypt a value.
    HELP

    SECRET_ENCRYPT_HELP = <<~HELP
      NAME
          encrypt

      USAGE
        bolt secret encrypt <plaintext> [options]

      DESCRIPTION
          Encrypt a value.
    HELP

    TASK_HELP = <<~HELP
      NAME
          task

      USAGE
          bolt task <action> [options]

      DESCRIPTION
          Show and run Bolt tasks.

      ACTIONS
          run          Run a Bolt task
          show         Show available tasks and task documentation
    HELP

    TASK_RUN_HELP = <<~HELP
      NAME
          run

      USAGE
          bolt task run <task> [parameters] [options]

      DESCRIPTION
          Run a task on the specified targets.

          Parameters take the form <parameter>=<value>.

      EXAMPLES
          bolt task run package --targets target1,target2 action=status name=bash
    HELP

    TASK_SHOW_HELP = <<~HELP
      NAME
          show

      USAGE
          bolt task show [task] [options]

      DESCRIPTION
          Show available tasks and task documentation.

          Omitting the name of a task will display a list of tasks available
          in the Bolt project.

          Providing the name of a task will display detailed documentation for
          the task, including a list of available parameters.

      EXAMPLES
          Display a list of available tasks
            bolt task show
          Display documentation for the canary task
            bolt task show canary
    HELP

    attr_reader :warnings
    def initialize(options)
      super()

      @options = options
      @warnings = []

      separator "\nINVENTORY OPTIONS"
      define('-n', '--nodes NODES',
             'Alias for --targets',
             'Deprecated in favor of --targets') do |nodes|
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
      define('--noop', 'See what changes Bolt will make without actually executing the changes') do |_|
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
      define('--detail', 'Show resolved configuration for the targets') do |detail|
        @options[:detail] = detail
      end

      separator "\nAUTHENTICATION OPTIONS"
      define('-u', '--user USER', 'User to authenticate as') do |user|
        @options[:user] = user
      end
      define('-p', '--password [PASSWORD]',
             'Password to authenticate with') do |password|
        if password.nil?
          msg = "Optional parameter for --password is deprecated and will no longer prompt for password. " \
                "Use the prompt plugin or --password-prompt instead to prompt for passwords."
          @warnings << { option: 'password', msg: msg }
          STDOUT.print "Please enter your password: "
          @options[:password] = STDIN.noecho(&:gets).chomp
          STDOUT.puts
        else
          @options[:password] = password
        end
      end
      define('--password-prompt', 'Prompt for user to input password') do |_password|
        STDERR.print "Please enter your password: "
        @options[:password] = STDIN.noecho(&:gets).chomp
        STDERR.puts
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

      separator "\nESCALATION OPTIONS"
      define('--run-as USER', 'User to run as using privilege escalation') do |user|
        @options[:'run-as'] = user
      end
      define('--sudo-password [PASSWORD]',
             'Password for privilege escalation') do |password|
        if password.nil?
          msg = "Optional parameter for --sudo-password is deprecated and will no longer prompt for password. " \
                "Use the prompt plugin or --sudo-password-prompt instead to prompt for passwords."
          @warnings << { option: 'sudo-password', msg: msg }
          STDOUT.print "Please enter your privilege escalation password: "
          @options[:'sudo-password'] = STDIN.noecho(&:gets).chomp
          STDOUT.puts
        else
          @options[:'sudo-password'] = password
        end
      end
      define('--sudo-password-prompt', 'Prompt for user to input escalation password') do |_password|
        STDERR.print "Please enter your privilege escalation password: "
        @options[:'sudo-password'] = STDIN.noecho(&:gets).chomp
        STDERR.puts
      end
      define('--sudo-executable EXEC', "Specify an executable for running as another user.",
             "This option is experimental.") do |exec|
        @options[:'sudo-executable'] = exec
      end

      separator "\nRUN CONTEXT OPTIONS"
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
             'Specify where to load config from (default: ~/.puppetlabs/bolt/bolt.yaml). ' \
             'Directory containing bolt.yaml will be used as the Boltdir.') do |path|
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

      separator "\nTRANSPORT OPTIONS"
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

      separator "\nDISPLAY OPTIONS"
      define('--filter FILTER', 'Filter tasks and plans by a matching substring') do |filter|
        unless /^[a-z0-9_:]+$/.match(filter)
          msg = "Illegal characters in filter string '#{filter}'. Filters must match a legal "\
                "task or plan name."
          raise Bolt::CLIError, msg
        end
        @options[:filter] = filter
      end
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

      separator "\nGLOBAL OPTIONS"
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

      define('--plugin PLUGIN', 'Select the plugin to use') do |plug|
        @options[:plugin] = plug
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
