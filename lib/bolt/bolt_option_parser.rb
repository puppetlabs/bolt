# frozen_string_literal: true

# Note this file includes very few 'requires' because it expects to be used from the CLI.

require 'optparse'

module Bolt
  class BoltOptionParser < OptionParser
    PROJECT_PATHS = %w[project].freeze
    OPTIONS = { inventory: %w[targets query rerun],
                authentication: %w[user password password-prompt private-key host-key-check ssl ssl-verify],
                escalation: %w[run-as sudo-password sudo-password-prompt sudo-executable],
                run_context: %w[concurrency inventoryfile save-rerun cleanup],
                global_config_setters: PROJECT_PATHS + %w[modulepath],
                transports: %w[transport connect-timeout tty native-ssh ssh-command copy-command],
                display: %w[format color verbose trace],
                global: %w[help version log-level clear-cache] }.freeze

    ACTION_OPTS = OPTIONS.values.flatten.freeze

    def get_help_text(subcommand, action = nil)
      case subcommand
      when 'apply'
        { flags: ACTION_OPTS + %w[noop execute compile-concurrency hiera-config],
          banner: APPLY_HELP }
      when 'command'
        case action
        when 'run'
          { flags: ACTION_OPTS + %w[env-var],
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
        when 'download'
          { flags: ACTION_OPTS,
            banner: FILE_DOWNLOAD_HELP }
        else
          { flags: OPTIONS[:global],
            banner: FILE_HELP }
        end
      when 'inventory'
        case action
        when 'show'
          { flags: OPTIONS[:inventory] + OPTIONS[:global] +
            PROJECT_PATHS + %w[format inventoryfile detail],
            banner: INVENTORY_SHOW_HELP }
        else
          { flags: OPTIONS[:global],
            banner: INVENTORY_HELP }
        end
      when 'group'
        case action
        when 'show'
          { flags: OPTIONS[:global] + PROJECT_PATHS + %w[format inventoryfile],
            banner: GROUP_SHOW_HELP }
        else
          { flags: OPTIONS[:global],
            banner: GROUP_HELP }
        end
      when 'guide'
        { flags: OPTIONS[:global] + %w[format],
          banner: GUIDE_HELP }
      when 'module'
        case action
        when 'add'
          { flags: OPTIONS[:global] + PROJECT_PATHS,
            banner: MODULE_ADD_HELP }
        when 'generate-types'
          { flags: OPTIONS[:global] + OPTIONS[:global_config_setters],
            banner: MODULE_GENERATETYPES_HELP }
        when 'install'
          { flags: OPTIONS[:global] + PROJECT_PATHS + %w[force resolve],
            banner: MODULE_INSTALL_HELP }
        when 'show'
          { flags: OPTIONS[:global] + OPTIONS[:global_config_setters],
            banner: MODULE_SHOW_HELP }
        else
          { flags: OPTIONS[:global],
            banner: MODULE_HELP }
        end
      when 'plan'
        case action
        when 'convert'
          { flags: OPTIONS[:global] + OPTIONS[:global_config_setters],
            banner: PLAN_CONVERT_HELP }
        when 'new'
          { flags: OPTIONS[:global] + PROJECT_PATHS + %w[pp],
            banner: PLAN_NEW_HELP }
        when 'run'
          { flags: ACTION_OPTS + %w[params compile-concurrency tmpdir hiera-config],
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
          { flags: OPTIONS[:global] + %w[modules],
            banner: PROJECT_INIT_HELP }
        when 'migrate'
          { flags: OPTIONS[:global] + PROJECT_PATHS + %w[inventoryfile],
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
          { flags: ACTION_OPTS + %w[tmpdir env-var],
            banner: SCRIPT_RUN_HELP }
        else
          { flags: OPTIONS[:global],
            banner: SCRIPT_HELP }
        end
      when 'secret'
        case action
        when 'createkeys'
          { flags: OPTIONS[:global] + OPTIONS[:global_config_setters] + %w[plugin force],
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
          file              Copy files between the controller and targets
          group             Show the list of groups in the inventory
          guide             View guides for Bolt concepts and features
          inventory         Show the list of targets an action would run on
          module            Manage Bolt project modules
          plan              Convert, create, show, and run Bolt plans
          project           Create and migrate Bolt projects
          puppetfile        Install and list modules and generate type references
          script            Upload a local script and run it remotely
          secret            Create encryption keys and encrypt and decrypt values
          task              Show and run Bolt tasks

      GUIDES
          For a list of guides on Bolt's concepts and features, run 'bolt guide'.
    HELP

    APPLY_HELP = <<~HELP
      NAME
          apply

      USAGE
          bolt apply [manifest.pp] [options]

      DESCRIPTION
          Apply Puppet manifest code on the specified targets.

      EXAMPLES
          bolt apply manifest.pp -t target
          bolt apply -e "file { '/etc/puppetlabs': ensure => present }" -t target
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
          Copy files and directories between the controller and targets

      ACTIONS
          download      Download a file or directory to the controller
          upload        Upload a local file or directory from the controller
    HELP

    FILE_DOWNLOAD_HELP = <<~HELP
      NAME
          download

      USAGE
          bolt file download <src> <dest> [options]

      DESCRIPTION
          Download a file or directory from one or more targets.

          Downloaded files and directories are saved to the a subdirectory
          matching the target's name under the destination directory. The
          destination directory is expanded relative to the downloads
          subdirectory of the project directory.

      EXAMPLES
          bolt file download /etc/ssh_config ssh_config -t all
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

    GUIDE_HELP = <<~HELP
      NAME
          guide

      USAGE
          bolt guide [topic] [options]

      DESCRIPTION
          View guides for Bolt's concepts and features.

          Omitting a topic will display a list of available guides,
          while providing a topic will display the relevant guide.

      EXAMPLES
          View a list of available guides
            bolt guide
          View the 'project' guide page
            bolt guide project
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

    MODULE_HELP = <<~HELP
      NAME
          module
      
      USAGE
          bolt module <action> [options]

      DESCRIPTION
          Manage Bolt project modules

          The module command is only supported when a project is configured
          with the 'modules' key.

      ACTIONS
          add                   Add a module to the project
          generate-types        Generate type references to register in plans
          install               Install the project's modules
          show                  List modules available to the Bolt project
    HELP

    MODULE_ADD_HELP = <<~HELP
      NAME
          add
      
      USAGE
          bolt module add <module> [options]

      DESCRIPTION
          Add a module to the project.

          Module declarations are loaded from the project's configuration
          file. Bolt will automatically resolve all module dependencies,
          generate a Puppetfile, and install the modules.

          The module command is only supported when a project is configured
          with the 'modules' key.
    HELP

    MODULE_GENERATETYPES_HELP = <<~HELP
      NAME
          generate-types

      USAGE
          bolt module generate-types [options]

      DESCRIPTION
          Generate type references to register in plans.

          The module command is only supported when a project is configured
          with the 'modules' key.
    HELP

    MODULE_INSTALL_HELP = <<~HELP
      NAME
          install
      
      USAGE
          bolt module install [options]

      DESCRIPTION
          Install the project's modules.

          Module declarations are loaded from the project's configuration
          file. Bolt will automatically resolve all module dependencies,
          generate a Puppetfile, and install the modules.
    HELP

    MODULE_SHOW_HELP = <<~HELP
      NAME
          show

      USAGE
          bolt module show [options]

      DESCRIPTION
          List modules available to the Bolt project.

          The module command is only supported when a project is configured
          with the 'modules' key.
    HELP

    PLAN_HELP = <<~HELP
      NAME
          plan

      USAGE
          bolt plan <action> [parameters] [options]

      DESCRIPTION
          Convert, create, show, and run Bolt plans.

      ACTIONS
          convert       Convert a YAML plan to a Bolt plan
          new           Create a new plan in the current project
          run           Run a plan on the specified targets
          show          Show available plans and plan documentation
    HELP

    PLAN_CONVERT_HELP = <<~HELP
      NAME
          convert

      USAGE
          bolt plan convert <path> [options]

      DESCRIPTION
          Convert a YAML plan to a Puppet language plan and print the converted plan to stdout.

          Converting a YAML plan may result in a plan that is syntactically
          correct but has different behavior. Always verify a converted plan's
          functionality. Note that the converted plan is not written to a file.

      EXAMPLES
          bolt plan convert path/to/plan/myplan.yaml
    HELP

    PLAN_NEW_HELP = <<~HELP
      NAME
          new
      
      USAGE
          bolt plan new <plan> [options]
      
      DESCRIPTION
          Create a new plan in the current project.

      EXAMPLES
          bolt plan new myproject::myplan
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
          Display a list of available plans
            bolt plan show
          Display documentation for the aggregate::count plan
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
          bolt project init [name] [options]

      DESCRIPTION
          Create a new Bolt project in the current working directory.

          Specify a name for the Bolt project. Defaults to the basename of the current working directory.

      EXAMPLES
          Create a new Bolt project using the directory as the project name.
            bolt project init
          Create a new Bolt project with a specified name.
            bolt project init myproject
          Create a new Bolt project with existing modules.
            bolt project init --modules puppetlabs-apt,puppetlabs-ntp
    HELP

    PROJECT_MIGRATE_HELP = <<~HELP
      NAME
          migrate

      USAGE
          bolt project migrate [options]

      DESCRIPTION
          Migrate a Bolt project to use current best practices and the latest version of configuration files.
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
          install               Install modules from a Puppetfile into a project
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
          Install modules from a Puppetfile into a project
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

          Parameters take the form parameter=value.

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

    def initialize(options)
      super()

      @options = options

      separator "\nINVENTORY OPTIONS"
      define('-t', '--targets TARGETS',
             'Identifies the targets of command.',
             'Enter a comma-separated list of target URIs or group names.',
             "Or read a target list from an input file '@<file>' or stdin '-'.",
             'Example: --targets localhost,target_group,ssh://nix.com:23,winrm://windows.puppet.com',
             'URI format is [protocol://]host[:port]',
             "SSH is the default protocol; may be #{TRANSPORTS.keys.join(', ')}",
             'For Windows targets, specify the winrm:// protocol if it has not be configured',
             'For SSH, port defaults to `22`',
             'For WinRM, port defaults to `5985` or `5986` based on the --[no-]ssl setting') do |targets|
        @options[:targets] ||= []
        @options[:targets] << Bolt::Util.get_arg_input(targets)
      end
      define('-q', '--query QUERY', 'Query PuppetDB to determine the targets') do |query|
        @options[:query] = query
      end
      define('--rerun FILTER', 'Retry on targets from the last run',
             "'all' all targets that were part of the last run.",
             "'failure' targets that failed in the last run.",
             "'success' targets that succeeded in the last run.") do |rerun|
        @options[:rerun] = rerun
      end
      define('--noop', 'See what changes Bolt will make without actually executing the changes') do |_|
        @options[:noop] = true
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
      define('-p', '--password PASSWORD',
             'Password to authenticate with') do |password|
        @options[:password] = password
      end
      define('--password-prompt', 'Prompt for user to input password') do |_password|
        $stderr.print "Please enter your password: "
        @options[:password] = $stdin.noecho(&:gets).chomp
        $stderr.puts
      end
      define('--private-key KEY', 'Path to private ssh key to authenticate with') do |key|
        @options[:'private-key'] = File.expand_path(key)
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
      define('--sudo-password PASSWORD',
             'Password for privilege escalation') do |password|
        @options[:'sudo-password'] = password
      end
      define('--sudo-password-prompt', 'Prompt for user to input escalation password') do |_password|
        $stderr.print "Please enter your privilege escalation password: "
        @options[:'sudo-password'] = $stdin.noecho(&:gets).chomp
        $stderr.puts
      end
      define('--sudo-executable EXEC', "Specify an executable for running as another user.",
             "This option is experimental.") do |exec|
        @options[:'sudo-executable'] = exec
      end

      separator "\nRUN CONTEXT OPTIONS"
      define('-c', '--concurrency CONCURRENCY', Integer,
             'Maximum number of simultaneous connections') do |concurrency|
        @options[:concurrency] = concurrency
      end
      define('--compile-concurrency CONCURRENCY', Integer,
             'Maximum number of simultaneous manifest block compiles (default: number of cores)') do |concurrency|
        @options[:'compile-concurrency'] = concurrency
      end
      define('--[no-]cleanup',
             'Whether to clean up temporary files created on targets') do |cleanup|
        @options[:cleanup] = cleanup
      end
      define('-m', '--modulepath MODULES',
             "List of directories containing modules, separated by '#{File::PATH_SEPARATOR}'",
             'Directories are case-sensitive') do |modulepath|
        # When specified from the CLI, modulepath entries are relative to pwd
        @options[:modulepath] = modulepath.split(File::PATH_SEPARATOR).map do |moduledir|
          File.expand_path(moduledir)
        end
      end
      define('--project PATH',
             'Path to load the Bolt project from (default: autodiscovered from current dir)') do |path|
        @options[:project] = path
      end
      define('--hiera-config PATH',
             'Specify where to load Hiera config from (default: ~/.puppetlabs/bolt/hiera.yaml)') do |path|
        @options[:'hiera-config'] = File.expand_path(path)
      end
      define('-i', '--inventoryfile PATH',
             'Specify where to load inventory from (default: ~/.puppetlabs/bolt/inventory.yaml)') do |path|
        if ENV.include?(Bolt::Inventory::ENVIRONMENT_VAR)
          raise Bolt::CLIError, "Cannot pass inventory file when #{Bolt::Inventory::ENVIRONMENT_VAR} is set"
        end
        @options[:inventoryfile] = File.expand_path(path)
      end
      define('--[no-]save-rerun', 'Whether to update the rerun file after this command.') do |save|
        @options[:'save-rerun'] = save
      end

      separator "\nREMOTE ENVIRONMENT OPTIONS"
      define('--env-var ENVIRONMENT_VARIABLES', 'Environment variables to set on the target') do |envvar|
        unless envvar.include?('=')
          raise Bolt::CLIError, "Environment variables must be specified using 'myenvvar=key' format"
        end
        @options[:env_vars] ||= {}
        @options[:env_vars].store(*envvar.split('=', 2))
      end

      separator "\nTRANSPORT OPTIONS"
      define('--transport TRANSPORT', TRANSPORTS.keys.map(&:to_s),
             "Specify a default transport: #{TRANSPORTS.keys.join(', ')}") do |t|
        @options[:transport] = t
      end
      define('--[no-]native-ssh', 'Whether to shell out to native SSH or use the net-ssh Ruby library.',
             'This option is experimental') do |bool|
        @options[:'native-ssh'] = bool
      end
      define('--ssh-command EXEC', "Executable to use instead of the net-ssh Ruby library. ",
             "This option is experimental.") do |exec|
        @options[:'ssh-command'] = exec
      end
      define('--copy-command EXEC', "Command to copy files to remote hosts if using native SSH. ",
             "This option is experimental.") do |exec|
        @options[:'copy-command'] = exec
      end
      define('--connect-timeout TIMEOUT', Integer, 'Connection timeout in seconds (defaults vary)') do |timeout|
        @options[:'connect-timeout'] = timeout
      end
      define('--[no-]tty', 'Request a pseudo TTY on targets that support it') do |tty|
        @options[:tty] = tty
      end
      define('--tmpdir DIR', 'The directory to upload and execute temporary files on the target') do |tmpdir|
        @options[:tmpdir] = tmpdir
      end

      separator "\nMODULE OPTIONS"
      define('--[no-]resolve',
             'Use --no-resolve to install modules listed in the Puppetfile without resolving modules configured',
             'in Bolt project configuration') do |resolve|
        @options[:resolve] = resolve
      end

      separator "\nPLAN OPTIONS"
      define('--pp', 'Create a new Puppet language plan.') do |_|
        @options[:puppet] = true
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

      separator "\nADDITIONAL OPTIONS"
      define('--modules MODULES',
             'A comma-separated list of modules to install from the Puppet Forge',
             'when initializing a project. Resolves and installs all dependencies.') do |modules|
        @options[:modules] = modules.split(',').map { |mod| { 'name' => mod } }
      end
      define('--force', 'Force a destructive action') do |_force|
        @options[:force] = true
      end

      separator "\nGLOBAL OPTIONS"
      define('-h', '--help', 'Display help') do |_|
        @options[:help] = true
      end
      define('--version', 'Display the version') do |_|
        puts Bolt::VERSION
        raise Bolt::CLIExit
      end
      define('--log-level LEVEL',
             "Set the log level for the console. Available options are",
             "trace, debug, info, warn, error, fatal, any.") do |level|
        @options[:log] = { 'console' => { 'level' => level } }
      end
      define('--clear-cache',
             "Clear plugin cache before executing") do |_|
        @options[:clear_cache] = true
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
      json = Bolt::Util.get_arg_input(params)
      JSON.parse(json)
    rescue JSON::ParserError => e
      raise Bolt::CLIError, "Unable to parse --params value as JSON: #{e}"
    end
  end
end
