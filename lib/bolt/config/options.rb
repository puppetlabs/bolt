# frozen_string_literal: true

module Bolt
  class Config
    module Options
      # The following constants define the various configuration options available to Bolt.
      # Each constant is a hash where keys are the configuration option and values are the
      # data describing the option. Data includes the following keys:
      #   :def     The **documented** default value. This is the value that is displayed
      #            in the reference docs and is not used by Bolt to actually set a default
      #            value.
      #   :desc    The text description of the option that is displayed in documentation.
      #   :exmp    An example value for the option. This is used to generate an example
      #            configuration file in the reference docs.
      #   :type    The option's expected type. If an option accepts multiple types, this is
      #            an array of the accepted types. Any options that accept a Boolean value
      #            should use the [TrueClass, FalseClass] type.
      OPTIONS = {
        "apply_settings" => {
          desc: "A map of Puppet settings to use when applying Puppet code using the `apply` "\
                "plan function or the `bolt apply` command.",
          type: Hash
        },
        "color" => {
          desc: "Whether to use colored output when printing messages to the console.",
          type: [TrueClass, FalseClass],
          exmp: false,
          def: true
        },
        "compile-concurrency" => {
          desc: "The maximum number of simultaneous manifest block compiles.",
          type: Integer,
          exmp: 4,
          def: "Number of cores."
        },
        "concurrency" => {
          desc: "The number of threads to use when executing on remote targets.",
          type: Integer,
          exmp: 50,
          def: "100 or 1/7 the ulimit, whichever is lower."
        },
        "format" => {
          desc: "The format to use when printing results. Options are `human`, `json`, and `rainbow`.",
          type: String,
          exmp: "json",
          def:  "human"
        },
        "hiera-config" => {
          desc: "The path to your Hiera config.",
          type: String,
          def:  "project/hiera.yaml",
          exmp: "~/.puppetlabs/bolt/hiera.yaml"
        },
        "inventory-config" => {
          desc: "A map of default configuration options for the inventory. This includes options "\
                "for setting the default transport to use when connecting to targets, as well as "\
                "options for configuring the default behavior of each transport.",
          type: Hash
        },
        "inventoryfile" => {
          desc: "The path to a structured data inventory file used to refer to groups of targets on the command "\
                "line and from plans. Read more about using inventory files in [Inventory "\
                "files](inventory_file_v2.md).",
          type: String,
          def:  "project/inventory.yaml",
          exmp: "~/.puppetlabs/bolt/inventory.yaml"
        },
        "log" => {
          desc: "A map of configuration for the logfile output. Configuration can be set for "\
                "`console` and individual log files, such as `~/.puppetlabs/bolt/debug.log`. "\
                "Each key in the map is the logfile output to configure, with the corresponding "\
                "value configuring the logfile output.",
          type: Hash,
          exmp: { "console" => { "level" => "info" },
                  "~/logs/debug.log" => { "append" => false, "level" => "debug" } }
        },
        "modulepath" => {
          desc: "An array of directories that Bolt loads content such as plans and tasks from. Read more "\
                "about modules in [Module structure](module_structure.md).",
          type: [Array, String],
          def:  ["project/modules", "project/site-modules", "project/site"],
          exmp: ["~/.puppetlabs/bolt/modules", "~/.puppetlabs/bolt/site-modules"]
        },
        "name" => {
          desc: "The name of the Bolt project. When this option is configured, the project is considered a "\
                "[Bolt project](experimental_features.md#bolt-projects), allowing Bolt to load content from "\
                "the project directory as though it were a module.",
          type: String,
          exmp: "myproject"
        },
        "plans" => {
          desc: "A list of plan names to show in `bolt plan show` output, if they exist. This option is used to "\
                "limit the visibility of plans for users of the project. For example, project authors might want to "\
                "limit the visibility of plans that are bundled with Bolt or plans that should only be run as "\
                "part of another plan. When this option is not configured, all plans are visible. This "\
                "option does not prevent users from running plans that are not part of this list.",
          type: Array,
          exmp: ["myproject", "myproject::foo", "myproject::bar"]
        },
        "plugin_hooks" => {
          desc: "A map of [plugin hooks](writing_plugins.md#hooks) and which plugins a hook should use. "\
                "The only configurable plugin hook is `puppet_library`, which can use two possible plugins: "\
                "[`puppet_agent`](https://github.com/puppetlabs/puppetlabs-puppet_agent#puppet_agentinstall) "\
                "and [`task`](using_plugins.md#task).",
          type: Hash,
          exmp: { "puppet_library" => { "plugin" => "puppet_agent", "version" => "6.15.0", "_run_as" => "root" } }
        },
        "plugins" => {
          desc: "A map of plugins and their configuration data, where each key is the name of a plugin and its "\
                "value is a map of configuration data. Configurable options are specified by the plugin. Read "\
                "more about configuring plugins in [Using plugins](using_plugins.md#configuring-plugins).",
          type: Hash,
          exmp: { "pkcs7" => { "keysize" => 1024 } }
        },
        "puppetdb" => {
          desc: "A map containing options for [configuring the Bolt PuppetDB client](bolt_connect_puppetdb.md).",
          type: Hash
        },
        "puppetfile" => {
          desc: "A map containing options for the `bolt puppetfile install` command.",
          type: Hash
        },
        "save-rerun" => {
          desc: "Whether to update `.rerun.json` in the Bolt project directory. If "\
                "your target names include passwords, set this value to `false` to avoid "\
                "writing passwords to disk.",
          type: [TrueClass, FalseClass],
          exmp: false,
          def:  true
        },
        "tasks" => {
          desc: "A list of task names to show in `bolt task show` output, if they exist. This option is used to "\
                "limit the visibility of tasks for users of the project. For example, project authors might want to "\
                "limit the visibility of tasks that are bundled with Bolt or plans that should only be run as "\
                "part of a larger workflow. When this option is not configured, all tasks are visible. This "\
                "option does not prevent users from running tasks that are not part of this list.",
          type: Array,
          exmp: ["myproject", "myproject::foo", "myproject::bar"]
        },
        "trusted-external-command" => {
          desc: "The path to an executable on the Bolt controller that can produce external trusted facts. "\
                "**External trusted facts are experimental in both Puppet and Bolt and this API may change or "\
                "be removed.**",
          type: String,
          exmp: "/etc/puppetlabs/facts/trusted_external.sh"
        }
      }.freeze

      # Options that configure the inventory, specifically the default transport
      # used by targets and the transports themselves. These options are used in
      # bolt.yaml, under a 'config' key in inventory.yaml, and under the
      # 'inventory-config' key in bolt-defaults.yaml.
      INVENTORY_OPTIONS = {
        "transport" => {
          desc: "The default transport to use when the transport for a target is not "\
                "specified in the URI.",
          type: String,
          def:  "ssh",
          exmp: "winrm"
        },
        "docker" => {
          desc: "A map of configuration options for the docker transport.",
          type: Hash,
          exmp: { "cleanup" => false, "service-url" => "https://docker.example.com" }
        },
        "local" => {
          desc: "A map of configuration options for the local transport. The set of available options is "\
                "platform dependent.",
          type: Hash,
          exmp: { "cleanup" => false, "tmpdir" => "/tmp/bolt" }
        },
        "pcp" => {
          desc: "A map of configuration options for the pcp transport.",
          type: Hash,
          exmp: { "job-poll-interval" => 15, "job-poll-timeout" => 30 }
        },
        "remote" => {
          desc: "A map of configuration options for the remote transport.",
          type: Hash,
          exmp: { "run-on" => "proxy_target" }
        },
        "ssh" => {
          desc: "A map of configuration options for the ssh transport.",
          type: Hash,
          exmp: { "password" => "hunter2!", "user" => "bolt" }
        },
        "winrm" => {
          desc: "A map of configuration options for the winrm transport.",
          type: Hash,
          exmp: { "password" => "hunter2!", "user" => "bolt" }
        }
      }.freeze

      # Suboptions for options that accept hashes.
      SUBOPTIONS = {
        "apply_settings" => {
          "show_diff" => {
            desc: "Whether to log and report a contextual diff when files are being replaced. See "\
                  "[Puppet documentation](https://puppet.com/docs/puppet/latest/configuration.html#showdiff) "\
                  "for details.",
            type: [TrueClass, FalseClass],
            exmp: true,
            def:  false
          }
        },
        "inventory-config" => INVENTORY_OPTIONS,
        "log" => {
          "append" => {
            desc: "Add output to an existing log file. Available only for logs output to a "\
                  "filepath.",
            type: [TrueClass, FalseClass],
            def:  true
          },
          "level" => {
            desc: "The type of information in the log. Either `debug`, `info`, `notice`, "\
                  "`warn`, or `error`.",
            type: String,
            def:  "`warn` for console, `notice` for file"
          }
        },
        "puppetdb" => {
          "cacert" => {
            desc: "The path to the ca certificate for PuppetDB.",
            type: String,
            exmp: "/etc/puppetlabs/puppet/ssl/certs/ca.pem"
          },
          "cert" => {
            desc: "The path to the client certificate file to use for authentication.",
            type: String,
            exmp: "/etc/puppetlabs/puppet/ssl/certs/my-host.example.com.pem"
          },
          "key" => {
            desc: "The private key for the certificate.",
            type: String,
            exmp: "/etc/puppetlabs/puppet/ssl/private_keys/my-host.example.com.pem"
          },
          "server_urls" => {
            desc: "An array containing the PuppetDB host to connect to. Include the protocol `https` "\
                  "and the port, which is usually `8081`. For example, "\
                  "`https://my-master.example.com:8081`.",
            type: Array,
            exmp: ["https://puppet.example.com:8081"]
          },
          "token" => {
            desc: "The path to the PE RBAC Token.",
            type: String,
            exmp: "~/.puppetlabs/token"
          }
        },
        "puppetfile" => {
          "forge" => {
            desc: "A subsection that can have its own `proxy` setting to set an HTTP proxy for Forge "\
                  "operations only, and a `baseurl` setting to specify a different Forge host.",
            type: Hash,
            exmp: { "baseurl" => "https://forge.example.com", "proxy" => "https://forgeapi.example.com" }
          },
          "proxy" => {
            desc: "The HTTP proxy to use for Git and Forge operations.",
            type: String,
            exmp: "https://forgeapi.example.com"
          }
        }
      }.freeze

      # Options that are available in a bolt.yaml file
      BOLT_OPTIONS = %w[
        apply_settings
        color
        compile-concurrency
        concurrency
        format
        hiera-config
        inventoryfile
        log
        modulepath
        plugin_hooks
        plugins
        puppetdb
        puppetfile
        save-rerun
        trusted-external-command
      ].freeze

      # Options that are available in a bolt-defaults.yaml file
      BOLT_DEFAULTS_OPTIONS = %w[
        color
        compile-concurrency
        concurrency
        format
        inventory-config
        plugin_hooks
        plugins
        puppetdb
        puppetfile
        save-rerun
      ].freeze

      # Options that are available in a bolt-project.yaml file
      BOLT_PROJECT_OPTIONS = %w[
        apply_settings
        color
        compile-concurrency
        concurrency
        format
        hiera-config
        inventoryfile
        log
        modulepath
        name
        plans
        plugin_hooks
        plugins
        puppetdb
        puppetfile
        save-rerun
        tasks
        trusted-external-command
      ].freeze
    end
  end
end
