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
                display: %w[format color verbose trace stream],
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
      when 'lookup'
        { flags: ACTION_OPTS + %w[hiera-config plan-hierarchy],
          banner: LOOKUP_HELP }
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
      when 'plugin'
        case action
        when 'show'
          { flags: OPTIONS[:global] + %w[color format modulepath project],
            banner: PLUGIN_SHOW_HELP }
        else
          { flags: OPTIONS[:global],
            banner: PLUGIN_HELP }
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

    COLORS = {
      cyan: "36"
    }.freeze

    def self.colorize(color, string)
      if $stdout.isatty
        "\033[#{COLORS[color]}m#{string}\033[0m"
      else
        string
      end
    end

    BANNER = <<~HELP
      #{colorize(:cyan, 'Name')}
          bolt

      #{colorize(:cyan, 'Usage')}
          bolt <subcommand> [action] [options]

      #{colorize(:cyan, 'Description')}
          Bolt is an orchestration tool that automates the manual work it takes to
          maintain your infrastructure.

      #{colorize(:cyan, 'Subcommands')}
          apply             Apply Puppet manifest code
          command           Run a command remotely
          file              Copy files between the controller and targets
          group             Show the list of groups in the inventory
          guide             View guides for Bolt concepts and features
          inventory         Show the list of targets an action would run on
          module            Manage Bolt project modules
          lookup            Look up a value with Hiera
          plan              Convert, create, show, and run Bolt plans
          plugin            Show available plugins
          project           Create and migrate Bolt projects
          script            Upload a local script and run it remotely
          secret            Create encryption keys and encrypt and decrypt values
          task              Show and run Bolt tasks

      #{colorize(:cyan, 'Guides')}
          For a list of guides on Bolt's concepts and features, run 'bolt guide'.
          Find Bolt's documentation at https://bolt.guide.
    HELP

    APPLY_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          apply

      #{colorize(:cyan, 'Usage')}
          bolt apply [manifest] {--targets TARGETS | --query QUERY | --rerun FILTER}
            [options]

      #{colorize(:cyan, 'Description')}
          Apply Puppet manifest code on the specified targets.

      #{colorize(:cyan, 'Documentation')}
          For documentation see http://pup.pt/bolt-apply.

      #{colorize(:cyan, 'Examples')}
          bolt apply manifest.pp -t target
          bolt apply -e "file { '/etc/puppetlabs': ensure => present }" -t target
    HELP

    COMMAND_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          command

      #{colorize(:cyan, 'Usage')}
          bolt command <action> [options]

      #{colorize(:cyan, 'Description')}
          Run a command on the specified targets.

      #{colorize(:cyan, 'Documentation')}
          For documentation see http://pup.pt/bolt-commands.

      #{colorize(:cyan, 'Actions')}
          run         Run a command on the specified targets.
    HELP

    COMMAND_RUN_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          run

      #{colorize(:cyan, 'Usage')}
          bolt command run <command> {--targets TARGETS | --query QUERY | --rerun FILTER}
            [options]

      #{colorize(:cyan, 'Description')}
          Run a command on the specified targets.

      #{colorize(:cyan, 'Documentation')}
          For documentation see http://pup.pt/bolt-commands.

      #{colorize(:cyan, 'Examples')}
          bolt command run 'uptime' -t target1,target2
    HELP

    FILE_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          file

      #{colorize(:cyan, 'Usage')}
          bolt file <action> [options]

      #{colorize(:cyan, 'Description')}
          Copy files and directories between the controller and targets.

      #{colorize(:cyan, 'Documentation')}
          For documentation see http://pup.pt/bolt-commands.

      #{colorize(:cyan, 'Actions')}
          download      Download a file or directory to the controller
          upload        Upload a local file or directory from the controller
    HELP

    FILE_DOWNLOAD_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          download

      #{colorize(:cyan, 'Usage')}
          bolt file download <source> <destination> {--targets TARGETS | --query QUERY | --rerun FILTER}
            [options]

      #{colorize(:cyan, 'Description')}
          Download a file or directory from one or more targets.

          Downloaded files and directories are saved to the a subdirectory
          matching the target's name under the destination directory. The
          destination directory is expanded relative to the downloads
          subdirectory of the project directory.

      #{colorize(:cyan, 'Documentation')}
          For documentation see http://pup.pt/bolt-commands.

      #{colorize(:cyan, 'Examples')}
          bolt file download /etc/ssh_config ssh_config -t all
    HELP

    FILE_UPLOAD_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          upload

      #{colorize(:cyan, 'Usage')}
          bolt file upload <source> <destination> {--targets TARGETS | --query QUERY | --rerun FILTER}
            [options]

      #{colorize(:cyan, 'Description')}
          Upload a local file or directory.

      #{colorize(:cyan, 'Documentation')}
          For documentation see http://pup.pt/bolt-commands.

      #{colorize(:cyan, 'Examples')}
          bolt file upload /tmp/source /etc/profile.d/login.sh -t target1
    HELP

    GROUP_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          group

      #{colorize(:cyan, 'Usage')}
          bolt group <action> [options]

      #{colorize(:cyan, 'Description')}
          Show the list of groups in the inventory.

      #{colorize(:cyan, 'Documentation')}
          To learn more about the inventory run 'bolt guide inventory'.

      #{colorize(:cyan, 'Actions')}
          show          Show the list of groups in the inventory
    HELP

    GROUP_SHOW_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          show

      #{colorize(:cyan, 'Usage')}
          bolt group show [options]

      #{colorize(:cyan, 'Description')}
          Show the list of groups in the inventory.

      #{colorize(:cyan, 'Documentation')}
          To learn more about the inventory run 'bolt guide inventory'.
    HELP

    GUIDE_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          guide

      #{colorize(:cyan, 'Usage')}
          bolt guide [topic] [options]

      #{colorize(:cyan, 'Description')}
          View guides for Bolt's concepts and features.

          Omitting a topic will display a list of available guides,
          while providing a topic will display the relevant guide.

      #{colorize(:cyan, 'Examples')}
          View a list of available guides
            bolt guide
          View the 'project' guide page
            bolt guide project
    HELP

    INVENTORY_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          inventory

      #{colorize(:cyan, 'Usage')}
          bolt inventory <action> [options]

      #{colorize(:cyan, 'Description')}
          Show the list of targets an action would run on.

      #{colorize(:cyan, 'Documentation')}
          To learn more about the inventory run 'bolt guide inventory'.

      #{colorize(:cyan, 'Actions')}
          show          Show the list of targets an action would run on
    HELP

    INVENTORY_SHOW_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          show

      #{colorize(:cyan, 'Usage')}
          bolt inventory show [options]

      #{colorize(:cyan, 'Description')}
          Show the list of targets an action would run on. This command will list
          all targets in the project's inventory by default.

          To filter the targets in the list, use the --targets, --query, or --rerun
          options. To view detailed configuration and data for targets, use the
          --detail option. To learn more about the inventory run 'bolt guide inventory'.

      #{colorize(:cyan, 'Documentation')}
          To learn more about the inventory run 'bolt guide inventory'.
    HELP

    LOOKUP_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          lookup

      #{colorize(:cyan, 'Usage')}
          bolt lookup <key> {--targets TARGETS | --query QUERY | --rerun FILTER | --plan-hierarchy}
            [options]

      #{colorize(:cyan, 'Description')}
          Look up a value with Hiera.

      #{colorize(:cyan, 'Documentation')}
          Learn more about using Hiera with Bolt at https://pup.pt/bolt-hiera.

      #{colorize(:cyan, 'Examples')}
          bolt lookup password --targets servers
          bolt lookup password --plan-hierarchy variable=value
    HELP

    MODULE_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          module
      
      #{colorize(:cyan, 'Usage')}
          bolt module <action> [options]

      #{colorize(:cyan, 'Description')}
          Manage Bolt project modules.

      #{colorize(:cyan, 'Documentation')}
          To learn more about Bolt modules run 'bolt guide module'.

      #{colorize(:cyan, 'Actions')}
          add                   Add a module to the project
          generate-types        Generate type references to register in plans
          install               Install the project's modules
          show                  List modules available to the Bolt project
    HELP

    MODULE_ADD_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          add
      
      #{colorize(:cyan, 'Usage')}
          bolt module add <module> [options]

      #{colorize(:cyan, 'Description')}
          Add a module to the project.

          Module declarations are loaded from the project's configuration
          file. Bolt will automatically resolve all module dependencies,
          generate a Puppetfile, and install the modules.

      #{colorize(:cyan, 'Documentation')}
          To learn more about Bolt modules, run 'bolt guide module'.
    HELP

    MODULE_GENERATETYPES_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          generate-types

      #{colorize(:cyan, 'Usage')}
          bolt module generate-types [options]

      #{colorize(:cyan, 'Description')}
          Generate type references to register in plans. To learn more about
          Bolt modules, run 'bolt guide module'.

      #{colorize(:cyan, 'Documentation')}
          To learn more about Bolt modules, run 'bolt guide module'.
    HELP

    MODULE_INSTALL_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          install
      
      #{colorize(:cyan, 'Usage')}
          bolt module install [options]

      #{colorize(:cyan, 'Description')}
          Install the project's modules.

          Module declarations are loaded from the project's configuration
          file. Bolt will automatically resolve all module dependencies,
          generate a Puppetfile, and install the modules.

      #{colorize(:cyan, 'Documentation')}
          To learn more about Bolt modules, run 'bolt guide module'.
    HELP

    MODULE_SHOW_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          show

      #{colorize(:cyan, 'Usage')}
          bolt module show [options]

      #{colorize(:cyan, 'Description')}
          List modules available to the Bolt project.

      #{colorize(:cyan, 'Documentation')}
          To learn more about Bolt modules, run 'bolt guide module'.
    HELP

    PLAN_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          plan

      #{colorize(:cyan, 'Usage')}
          bolt plan <action> [options]

      #{colorize(:cyan, 'Description')}
          Convert, create, show, and run Bolt plans.

      #{colorize(:cyan, 'Documentation')}
          Learn more about Bolt plans at https://pup.pt/bolt-plans.

      #{colorize(:cyan, 'Actions')}
          convert       Convert a YAML plan to a Bolt plan
          new           Create a new plan in the current project
          run           Run a plan on the specified targets
          show          Show available plans and plan documentation
    HELP

    PLAN_CONVERT_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          convert

      #{colorize(:cyan, 'Usage')}
          bolt plan convert <plan name> [options]

      #{colorize(:cyan, 'Description')}
          Convert a YAML plan to a Puppet language plan and print the converted
          plan to stdout.

          Converting a YAML plan might result in a plan that is syntactically
          correct but has different behavior. Always verify a converted plan's
          functionality. Note that the converted plan is not written to a file.

      #{colorize(:cyan, 'Documentation')}
          Learn more about Bolt plans at https://pup.pt/bolt-plans.

      #{colorize(:cyan, 'Examples')}
          bolt plan convert myproject::myplan
          bolt plan convert path/to/plan/myplan.yaml
    HELP

    PLAN_NEW_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          new
      
      #{colorize(:cyan, 'Usage')}
          bolt plan new <plan name> [options]
      
      #{colorize(:cyan, 'Description')}
          Create a new plan in the current project.

      #{colorize(:cyan, 'Documentation')}
          Learn more about Bolt plans at https://pup.pt/bolt-plans.

      #{colorize(:cyan, 'Examples')}
          bolt plan new myproject::myplan
    HELP

    PLAN_RUN_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          run

      #{colorize(:cyan, 'Usage')}
          bolt plan run <plan name> [parameters] [options]

      #{colorize(:cyan, 'Description')}
          Run a plan on the specified targets.

      #{colorize(:cyan, 'Documentation')}
          Learn more about Bolt plans at https://pup.pt/bolt-plans.

      #{colorize(:cyan, 'Examples')}
          bolt plan run canary --targets target1,target2 command=hostname
    HELP

    PLAN_SHOW_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          show

      #{colorize(:cyan, 'Usage')}
          bolt plan show [plan name] [options]

      #{colorize(:cyan, 'Description')}
          Show available plans and plan documentation.

          Omitting the name of a plan will display a list of plans available
          in the Bolt project.

          Providing the name of a plan will display detailed documentation for
          the plan, including a list of available parameters.

      #{colorize(:cyan, 'Documentation')}
          Learn more about Bolt plans at https://pup.pt/bolt-plans.

      #{colorize(:cyan, 'Examples')}
          Display a list of available plans
            bolt plan show
          Display documentation for the aggregate::count plan
            bolt plan show aggregate::count
    HELP

    PLUGIN_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          plugin

      #{colorize(:cyan, 'Usage')}
          bolt plugin <action> [options]

      #{colorize(:cyan, 'Description')}
          Show available plugins.

      #{colorize(:cyan, 'Documentation')}
          Learn more about Bolt plugins at https://pup.pt/bolt-plugins.

      #{colorize(:cyan, 'Actions')}
          show          Show available plugins
    HELP

    PLUGIN_SHOW_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          show

      #{colorize(:cyan, 'Usage')}
          bolt plugin show [options]

      #{colorize(:cyan, 'Description')}
          Show available plugins.

      #{colorize(:cyan, 'Documentation')}
          Learn more about Bolt plugins at https://pup.pt/bolt-plugins.
    HELP

    PROJECT_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          project

      #{colorize(:cyan, 'Usage')}
          bolt project <action> [options]

      #{colorize(:cyan, 'Description')}
          Create and migrate Bolt projects

      #{colorize(:cyan, 'Documentation')}
          To learn more about Bolt projects, run 'bolt guide project'.

      #{colorize(:cyan, 'Actions')}
          init              Create a new Bolt project
          migrate           Migrate a Bolt project to the latest version
    HELP

    PROJECT_INIT_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          init

      #{colorize(:cyan, 'Usage')}
          bolt project init [name] [options]

      #{colorize(:cyan, 'Description')}
          Create a new Bolt project in the current working directory.

          Specify a name for the Bolt project. Defaults to the basename of the current working directory.

      #{colorize(:cyan, 'Documentation')}
          To learn more about Bolt projects, run 'bolt guide project'.

      #{colorize(:cyan, 'Examples')}
          Create a new Bolt project using the directory as the project name.
            bolt project init
          Create a new Bolt project with a specified name.
            bolt project init myproject
          Create a new Bolt project with existing modules.
            bolt project init --modules puppetlabs-apt,puppetlabs-ntp
    HELP

    PROJECT_MIGRATE_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          migrate

      #{colorize(:cyan, 'Usage')}
          bolt project migrate [options]

      #{colorize(:cyan, 'Description')}
          Migrate a Bolt project to use current best practices and the latest version of
          configuration files.

      #{colorize(:cyan, 'Documentation')}
          To learn more about Bolt projects, run 'bolt guide project'.
    HELP

    SCRIPT_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          script

      #{colorize(:cyan, 'Usage')}
          bolt script <action> [options]

      #{colorize(:cyan, 'Description')}
          Run a script on the specified targets.

      #{colorize(:cyan, 'Documentation')}
          Learn more about running scripts at https://pup.pt/bolt-commands.

      #{colorize(:cyan, 'Actions')}
          run         Run a script on the specified targets.
    HELP

    SCRIPT_RUN_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          run

      #{colorize(:cyan, 'Usage')}
          bolt script run <script> [arguments] {--targets TARGETS | --query QUERY | --rerun FILTER}
            [options]

      #{colorize(:cyan, 'Description')}
          Run a script on the specified targets.

          Arguments passed to a script are passed literally and are not interpolated
          by the shell. Any arguments containing spaces or special characters should
          be quoted.

      #{colorize(:cyan, 'Documentation')}
          Learn more about running scripts at https://pup.pt/bolt-commands.

      #{colorize(:cyan, 'Examples')}
          bolt script run myscript.sh 'echo hello' --targets target1,target2
    HELP

    SECRET_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          secret

      #{colorize(:cyan, 'Usage')}
          bolt secret <action> [options]

      #{colorize(:cyan, 'Description')}
          Create encryption keys and encrypt and decrypt values.

      #{colorize(:cyan, 'Documentation')}
          Learn more about secrets plugins at http://pup.pt/bolt-plugins.

      #{colorize(:cyan, 'Actions')}
          createkeys           Create new encryption keys
          encrypt              Encrypt a value
          decrypt              Decrypt a value
    HELP

    SECRET_CREATEKEYS_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          createkeys

      #{colorize(:cyan, 'Usage')}
          bolt secret createkeys [options]

      #{colorize(:cyan, 'Description')}
          Create new encryption keys.

      #{colorize(:cyan, 'Documentation')}
          Learn more about secrets plugins at http://pup.pt/bolt-plugins.
    HELP

    SECRET_DECRYPT_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          decrypt

      #{colorize(:cyan, 'Usage')}
          bolt secret decrypt <ciphertext> [options]

      #{colorize(:cyan, 'Description')}
          Decrypt a value.

      #{colorize(:cyan, 'Documentation')}
          Learn more about secrets plugins at http://pup.pt/bolt-plugins.
    HELP

    SECRET_ENCRYPT_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          encrypt

      #{colorize(:cyan, 'Usage')}
        bolt secret encrypt <plaintext> [options]

      #{colorize(:cyan, 'Description')}
          Encrypt a value.

      #{colorize(:cyan, 'Documentation')}
          Learn more about secrets plugins at http://pup.pt/bolt-plugins.
    HELP

    TASK_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          task

      #{colorize(:cyan, 'Usage')}
          bolt task <action> [options]

      #{colorize(:cyan, 'Description')}
          Show and run Bolt tasks.

      #{colorize(:cyan, 'Documentation')}
          Learn more about Bolt tasks at http://pup.pt/bolt-tasks.

      #{colorize(:cyan, 'Actions')}
          run          Run a Bolt task
          show         Show available tasks and task documentation
    HELP

    TASK_RUN_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          run

      #{colorize(:cyan, 'Usage')}
          bolt task run <task name> [parameters] {--targets TARGETS | --query QUERY | --rerun FILTER}
            [options]

      #{colorize(:cyan, 'Description')}
          Run a task on the specified targets.

          Parameters take the form parameter=value.

      #{colorize(:cyan, 'Documentation')}
          Learn more about Bolt tasks at http://pup.pt/bolt-tasks.

      #{colorize(:cyan, 'Examples')}
          bolt task run package --targets target1,target2 action=status name=bash
    HELP

    TASK_SHOW_HELP = <<~HELP
      #{colorize(:cyan, 'Name')}
          show

      #{colorize(:cyan, 'Usage')}
          bolt task show [task name] [options]

      #{colorize(:cyan, 'Description')}
          Show available tasks and task documentation.

          Omitting the name of a task will display a list of tasks available
          in the Bolt project.

          Providing the name of a task will display detailed documentation for
          the task, including a list of available parameters.

      #{colorize(:cyan, 'Documentation')}
          Learn more about Bolt tasks at http://pup.pt/bolt-tasks.

      #{colorize(:cyan, 'Examples')}
          Display a list of available tasks
            bolt task show
          Display documentation for the canary task
            bolt task show canary
    HELP

    def initialize(options)
      super()

      @options = options

      separator "\n#{self.class.colorize(:cyan, 'Inventory options')}"
      define('-t', '--targets TARGETS', 'Identifies the targets of the command.',
             "For more information, see 'bolt guide targets'.") do |targets|
        @options[:targets] ||= []
        @options[:targets] << Bolt::Util.get_arg_input(targets)
      end
      define('-q', '--query QUERY', 'Query PuppetDB to determine the targets.') do |query|
        @options[:query] = query
      end
      define("--rerun FILTER", "Retry on targets from the last run.",
             "Available filters are 'all', 'failure', and 'success'.") do |rerun|
        @options[:rerun] = rerun
      end
      define('--noop', 'See what changes Bolt will make without actually executing the changes.') do |_|
        @options[:noop] = true
      end
      define('--params PARAMETERS',
             "Parameters to a task or plan as json, a json file '@<file>', or on stdin '-'.") do |params|
        @options[:params] = parse_params(params)
      end
      define('-e', '--execute CODE',
             "Puppet manifest code to apply to the targets.") do |code|
        @options[:code] = code
      end
      define('--detail', 'Show resolved configuration for the targets.') do |detail|
        @options[:detail] = detail
      end

      separator "\n#{self.class.colorize(:cyan, 'Authentication options')}"
      define('-u', '--user USER', 'User to authenticate as.') do |user|
        @options[:user] = user
      end
      define('-p', '--password PASSWORD',
             'Password to authenticate with.') do |password|
        @options[:password] = password
      end
      define('--password-prompt', 'Prompt for user to input password.') do |_password|
        $stderr.print "Please enter your password: "
        @options[:password] = $stdin.noecho(&:gets).chomp
        $stderr.puts
      end
      define('--private-key KEY', 'Path to private ssh key to authenticate with.') do |key|
        @options[:'private-key'] = File.expand_path(key)
      end
      define('--[no-]host-key-check', 'Check host keys with SSH.') do |host_key_check|
        @options[:'host-key-check'] = host_key_check
      end
      define('--[no-]ssl', 'Use SSL with WinRM.') do |ssl|
        @options[:ssl] = ssl
      end
      define('--[no-]ssl-verify', 'Verify remote host SSL certificate with WinRM.') do |ssl_verify|
        @options[:'ssl-verify'] = ssl_verify
      end

      separator "\n#{self.class.colorize(:cyan, 'Escalation options')}"
      define('--run-as USER', 'User to run as using privilege escalation.') do |user|
        @options[:'run-as'] = user
      end
      define('--sudo-password PASSWORD',
             'Password for privilege escalation.') do |password|
        @options[:'sudo-password'] = password
      end
      define('--sudo-password-prompt', 'Prompt for user to input escalation password.') do |_password|
        $stderr.print "Please enter your privilege escalation password: "
        @options[:'sudo-password'] = $stdin.noecho(&:gets).chomp
        $stderr.puts
      end
      define('--sudo-executable EXEC', "Experimental. Specify an executable for running as another user.") do |exec|
        @options[:'sudo-executable'] = exec
      end

      separator "\n#{self.class.colorize(:cyan, 'Run context options')}"
      define('-c', '--concurrency CONCURRENCY', Integer,
             'Maximum number of simultaneous connections.') do |concurrency|
        @options[:concurrency] = concurrency
      end
      define('--compile-concurrency CONCURRENCY', Integer,
             'Maximum number of simultaneous manifest block compiles (default: number of cores).') do |concurrency|
        @options[:'compile-concurrency'] = concurrency
      end
      define('--[no-]cleanup',
             'Whether to clean up temporary files created on targets.') do |cleanup|
        @options[:cleanup] = cleanup
      end
      define('-m', '--modulepath MODULES',
             "List of directories containing modules, separated by '#{File::PATH_SEPARATOR}'",
             'Directories are case-sensitive.') do |modulepath|
        # When specified from the CLI, modulepath entries are relative to pwd
        @options[:modulepath] = modulepath.split(File::PATH_SEPARATOR).map do |moduledir|
          File.expand_path(moduledir)
        end
      end
      define('--project PATH',
             'Path to load the Bolt project from (default: autodiscovered from current dir).') do |path|
        @options[:project] = path
      end
      define('--hiera-config PATH',
             'Specify where to load Hiera config from (default: <project>/hiera.yaml).') do |path|
        @options[:'hiera-config'] = File.expand_path(path)
      end
      define('-i', '--inventoryfile PATH',
             'Specify where to load inventory from (default: <project>/inventory.yaml).') do |path|
        if ENV.include?(Bolt::Inventory::ENVIRONMENT_VAR)
          raise Bolt::CLIError, "Cannot pass inventory file when #{Bolt::Inventory::ENVIRONMENT_VAR} is set"
        end
        @options[:inventoryfile] = File.expand_path(path)
      end
      define('--[no-]save-rerun', 'Whether to update the rerun file after this command.') do |save|
        @options[:'save-rerun'] = save
      end

      separator "\n#{self.class.colorize(:cyan, 'Remote environment options')}"
      define('--env-var ENVIRONMENT_VARIABLES', 'Environment variables to set on the target.') do |envvar|
        unless envvar.include?('=')
          raise Bolt::CLIError, "Environment variables must be specified using 'myenvvar=key' format"
        end
        @options[:env_vars] ||= {}
        @options[:env_vars].store(*envvar.split('=', 2))
      end

      separator "\n#{self.class.colorize(:cyan, 'Transport options')}"
      define('--transport TRANSPORT', TRANSPORTS.keys.map(&:to_s),
             "Specify a default transport: #{TRANSPORTS.keys.join(', ')}.",
             "For more information, see 'bolt guide transports'.") do |t|
        @options[:transport] = t
      end
      define('--[no-]native-ssh',
             'Experimental. Whether to shell out to native SSH or use the net-ssh Ruby library.') do |bool|
        @options[:'native-ssh'] = bool
      end
      define('--ssh-command EXEC', "Experimental. Executable to use instead of the net-ssh Ruby library.") do |exec|
        @options[:'ssh-command'] = exec
      end
      define('--copy-command EXEC',
             "Experimental. Command to copy files to remote hosts if using native SSH.") do |exec|
        @options[:'copy-command'] = exec
      end
      define('--connect-timeout TIMEOUT', Integer, 'Connection timeout in seconds (defaults vary).') do |timeout|
        @options[:'connect-timeout'] = timeout
      end
      define('--[no-]tty', 'Request a pseudo TTY on targets that support it.') do |tty|
        @options[:tty] = tty
      end
      define('--tmpdir DIR', 'The directory to upload and execute temporary files on the target.') do |tmpdir|
        @options[:tmpdir] = tmpdir
      end

      separator "\n#{self.class.colorize(:cyan, 'Module options')}"
      define('--[no-]resolve',
             'Use --no-resolve to install modules listed in the Puppetfile without resolving modules configured',
             'in Bolt project configuration.') do |resolve|
        @options[:resolve] = resolve
      end

      separator "\n#{self.class.colorize(:cyan, 'Lookup options')}"
      define('--plan-hierarchy', 'Look up a value with Hiera in the context of a specific plan.') do |_|
        @options[:plan_hierarchy] = true
      end

      separator "\n#{self.class.colorize(:cyan, 'Plan options')}"
      define('--pp', 'Create a new Puppet language plan.') do |_|
        @options[:puppet] = true
      end

      separator "\n#{self.class.colorize(:cyan, 'Display options')}"
      define('--filter FILTER', 'Filter tasks and plans by a matching substring.') do |filter|
        unless /^[a-z0-9_:]+$/.match(filter)
          msg = "Illegal characters in filter string '#{filter}'. Filters can "\
          "only include lowercase letters, numbers, underscores, and colons."
          raise Bolt::CLIError, msg
        end
        @options[:filter] = filter
      end
      define('--format FORMAT', 'Output format to use: human, json, or rainbow.') do |format|
        @options[:format] = format
      end
      define('--[no-]color', 'Whether to show output in color.') do |color|
        @options[:color] = color
      end
      define('-v', '--[no-]verbose', 'Display verbose logging.') do |value|
        @options[:verbose] = value
      end
      define('--stream',
             'Stream output from scripts and commands to the console.',
             'Run with --no-verbose to prevent Bolt from displaying output',
             'a second time after the action is completed.') do |_|
        @options[:stream] = true
      end
      define('--trace', 'Display error stack traces.') do |_|
        @options[:trace] = true
      end

      separator "\n#{self.class.colorize(:cyan, 'Additional options')}"
      define('--modules MODULES',
             'A comma-separated list of modules to install from the Puppet Forge',
             'when initializing a project. Resolves and installs all dependencies.') do |modules|
        @options[:modules] = modules.split(',').map { |mod| { 'name' => mod } }
      end
      define('--force', 'Force a destructive action.') do |_force|
        @options[:force] = true
      end

      separator "\n#{self.class.colorize(:cyan, 'Global options')}"
      define('-h', '--help', 'Display help.') do |_|
        @options[:help] = true
      end
      define('--version', 'Display the version.') do |_|
        @options[:version] = true
      end
      define('--log-level LEVEL',
             "Set the log level for the console. Available options are",
             "trace, debug, info, warn, error, fatal.") do |level|
        @options[:log] = { 'console' => { 'level' => level } }
      end
      define('--clear-cache',
             "Clear plugin cache before executing.") do |_|
        @options[:clear_cache] = true
      end
      define('--plugin PLUGIN', 'Select the plugin to use.') do |plug|
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

    def permute(args)
      super(args)
    rescue OptionParser::MissingArgument => e
      raise Bolt::CLIError, "Option '#{e.args.first}' needs a parameter"
    rescue OptionParser::InvalidArgument => e
      raise Bolt::CLIError, "Invalid parameter specified for option '#{e.args.first}': #{e.args[1]}"
    rescue OptionParser::InvalidOption, OptionParser::AmbiguousOption => e
      raise Bolt::CLIError, "Unknown argument '#{e.args.first}'"
    end
  end
end
