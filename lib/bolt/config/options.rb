# frozen_string_literal: true

require_relative '../../bolt/config/transport/docker'
require_relative '../../bolt/config/transport/local'
require_relative '../../bolt/config/transport/lxd'
require_relative '../../bolt/config/transport/orch'
require_relative '../../bolt/config/transport/podman'
require_relative '../../bolt/config/transport/remote'
require_relative '../../bolt/config/transport/ssh'
require_relative '../../bolt/config/transport/winrm'

module Bolt
  class Config
    module Options
      # Transport config classes. Used to load default transport config which
      # gets passed along to the inventory.
      TRANSPORT_CONFIG = {
        'docker' => Bolt::Config::Transport::Docker,
        'local'  => Bolt::Config::Transport::Local,
        'lxd'    => Bolt::Config::Transport::LXD,
        'pcp'    => Bolt::Config::Transport::Orch,
        'podman' => Bolt::Config::Transport::Podman,
        'remote' => Bolt::Config::Transport::Remote,
        'ssh'    => Bolt::Config::Transport::SSH,
        'winrm'  => Bolt::Config::Transport::WinRM
      }.freeze

      # Plugin definition. This is used by the JSON schemas to indicate that an option
      # accepts a plugin reference. Since this isn't used by Bolt to perform automatic
      # type validation, the :type key is set to a JSON type instead of a Ruby type.
      PLUGIN = {
        "_plugin" => {
          description: "A plugin reference.",
          type: "object",
          required: ["_plugin"],
          properties: {
            "_plugin" => {
              description: "The name of the plugin.",
              type: "string"
            },
            "_cache" => {
              description: "This feature is experimental. Enable plugin caching and set a time-to-live.",
              type: "object",
              required: ["ttl"],
              properties: {
                "ttl" => {
                  description: "Time in seconds to keep the plugin cache.",
                  type: "integer",
                  minimum: 0
                }
              }
            }
          }
        }
      }.freeze

      # Definitions used to validate config options.
      # https://github.com/puppetlabs/bolt/blob/main/schemas/README.md
      OPTIONS = {
        "analytics" => {
          description: "Whether to disable analytics. Setting this option to 'false' in the system-wide "\
                       "or user-level configuration will disable analytics for all projects, even if this "\
                       "option is set to 'true' at the project level.",
          type: [TrueClass, FalseClass],
          _example: false
        },
        "apply-settings" => {
          description: "A map of Puppet settings to use when applying Puppet code using the `apply` "\
                       "plan function or the `bolt apply` command.",
          type: Hash,
          properties: {
            "evaltrace" => {
              description: "Whether each resource should log when it is being evaluated. This allows "\
                           "you to interactively see exactly what is being done.",
              type: [TrueClass, FalseClass],
              _example: true,
              _default: false
            },
            "log_level" => {
              description: "The log level for logs in apply reports from Puppet. These can be seen "\
                           "in ApplyResults.",
              type: String,
              enum: %w[debug info notice warning err alert emerg crit],
              _example: "debug",
              _default: "notice"
            },
            "show_diff" => {
              description: "Whether to log and report a contextual diff.",
              type: [TrueClass, FalseClass],
              _example: true,
              _default: false
            },
            "trace" => {
              description: "Whether to print stack traces on some errors. Will print internal Ruby "\
                           "stack trace interleaved with Puppet function frames.",
              type: [TrueClass, FalseClass],
              _example: true,
              _default: false
            }
          },
          _plugin: false
        },
        "color" => {
          description: "Whether to use colored output when printing messages to the console.",
          type: [TrueClass, FalseClass],
          _plugin: false,
          _example: false,
          _default: true
        },
        "compile-concurrency" => {
          description: "The maximum number of simultaneous manifest block compiles.",
          type: Integer,
          minimum: 1,
          _plugin: false,
          _example: 5,
          _default: "Number of cores."
        },
        "concurrency" => {
          description: "The number of threads to use when executing on remote targets.",
          type: Integer,
          minimum: 1,
          _plugin: false,
          _example: 50,
          _default: "100 or 1/7 the ulimit, whichever is lower."
        },
        "disable-warnings" => {
          description: "An array of IDs of warnings to suppress. Warnings with a matching ID will not be logged "\
                       "by Bolt. If you are upgrading Bolt to a new major version, you should re-enable all warnings "\
                       "until you have finished upgrading.",
          type: Array,
          items: {
            type: String
          },
          _plugin: false,
          _example: ["powershell_2"]
        },
        "format" => {
          description: "The format to use when printing results.",
          type: String,
          enum: %w[human json rainbow],
          _plugin: false,
          _example: "json",
          _default: "human"
        },
        "future" => {
          description: "Enable new Bolt features that may include breaking changes.",
          type: Hash,
          properties: {
            "file_paths" => {
              description: "Load scripts from the `scripts/` directory of a module.",
              type: [TrueClass, FalseClass],
              _example: true,
              _default: false,
              _deprecation: "Bolt no longer honors this option and enables loading scripts from the scripts "\
                            "directory by default."
            },
            "script_interpreter" => {
              description: "Use a target's [`interpreters` configuration](bolt_transports_reference.md#interpreters) "\
                           "when running a script.",
              type: [TrueClass, FalseClass],
              _example: true,
              _default: false
            }
          },
          _plugin: false,
          _example: { 'script_interpreter' => true }
        },
        "hiera-config" => {
          description: "The path to the Hiera configuration file.",
          type: String,
          _plugin: false,
          _example: "~/.puppetlabs/bolt/hiera.yaml",
          _default: "project/hiera.yaml"
        },
        "inventory-config" => {
          description: "A map of default configuration options for the inventory. This includes options "\
                       "for setting the default transport to use when connecting to targets, as well as "\
                       "options for configuring the default behavior of each transport.",
          type: Hash,
          _plugin: false,
          _example: {}
        },
        "plugin-cache" => {
          description: "This feature is experimental. Enable plugin caching and set the time-to-live.",
          type: Hash,
          required: ["ttl"],
          properties: {
            "ttl" => {
              description: "Time in seconds to keep the plugin cache.",
              type: Integer,
              minimum: 0
            }
          },
          _plugin: false,
          _example: { "ttl" => 3600 }
        },
        "log" => {
          description: "A map of configuration for the logfile output. Under `log`, you can configure log options "\
                       "for `console` and add configuration for individual log files, such as "\
                       "`~/.puppetlabs/bolt/debug.log`. Individual log files must be valid filepaths. If the log "\
                       "file does not exist, then Bolt will create it before logging information. Set the value to "\
                       "`disable` to remove a log file defined at an earlier level of the config hierarchy. By "\
                       "default, Bolt logs to a bolt-debug.log file in the Bolt project directory.",
          type: Hash,
          properties: {
            "console" => {
              description: "Configuration for logs output to the console.",
              type: [String, Hash],
              enum: ['disable'],
              properties: {
                "level" => {
                  description: "The type of information to log.",
                  type: String,
                  enum: %w[trace debug error info warn fatal],
                  _default: "warn"
                }
              }
            }
          },
          additionalProperties: {
            description: "Configuration for the logfile output.",
            type: [String, Hash],
            enum: ['disable'],
            properties: {
              "append" => {
                description: "Whether to append output to an existing log file.",
                type: [TrueClass, FalseClass],
                _default: true
              },
              "level" => {
                description: "The type of information to log.",
                type: String,
                enum: %w[trace debug error info warn fatal],
                _default: "warn"
              }
            }
          },
          _plugin: false,
          _example: { "console" => { "level" => "info" },
                      "~/logs/debug.log" => { "append" => false, "level" => "debug" } }
        },
        "modulepath" => {
          description: "An array of directories that Bolt loads content such as plans and tasks from. Read more "\
                       "about modules in [Module structure](module_structure.md).",
          type: [Array, String],
          items: {
            type: String
          },
          _plugin: false,
          _example: ["~/.puppetlabs/bolt/modules", "~/.puppetlabs/bolt/site-modules"],
          _default: ["project/modules"]
        },
        "module-install" => {
          description: "Options that configure where Bolt downloads modules from. This option is only used when "\
                       "installing modules using the `bolt module add|install` commands and "\
                       "`Add|Install-BoltModule` cmdlets.",
          type: Hash,
          properties: {
            "forge" => {
              description: "A subsection for configuring connections to a Forge host.",
              type: Hash,
              properties: {
                "authorization_token" => {
                  description: "The token used to authorize requests to the Forge host. Must also specify "\
                               "`baseurl` when using this option.",
                  type: String,
                  _example: "Bearer eyJhbGciOiJIUzI1NiIsInR5c...",
                  _plugin: true
                },
                "baseurl" => {
                  description: "The URL to the Forge host.",
                  type: String,
                  format: "uri",
                  _example: "https://forge.example.com"
                },
                "proxy" => {
                  description: "The HTTP proxy to use for Forge operations.",
                  type: String,
                  format: "uri",
                  _example: "https://my-forge-proxy.com:8080"
                }
              },
              _example: {
                "authorization_token" => "Bearer eyJhbGciOiJIUzI1NiIsInR5c...",
                "baseurl" => "https://forge.example.com",
                "proxy" => "https://my-forge-proxy.com:8080"
              }
            },
            "proxy" => {
              description: "The HTTP proxy to use for Git and Forge operations.",
              type: String,
              format: "uri",
              _example: "https://my-proxy.com:8080"
            }
          },
          _plugin: false
        },
        "modules" => {
          description: "A list of module dependencies for the project. Each dependency is a map of data specifying "\
                       "the module to install. To install the project's module dependencies, run the `bolt module "\
                       "install` command. For more information about specifying modules, see [the "\
                       "documentation](https://pup.pt/bolt-module-specs).",
          type: Array,
          items: {
            type: [Hash, String],
            oneOf: [
              {
                required: ["name"],
                properties: {
                  "name" => {
                    description: "The name of the module.",
                    type: String
                  },
                  "resolve" => {
                    description: "Whether to resolve the module's dependencies when installing modules.",
                    type: [TrueClass, FalseClass]
                  },
                  "version_requirement" => {
                    description: "The version requirement for the module. Accepts a specific version (1.2.3), version "\
                                 "shorthand (1.2.x), or a version range (>= 1.2.0).",
                    type: String
                  }
                }
              },
              {
                required: %w[git ref],
                properties: {
                  "git" => {
                    description: "The URL to the public git repository.",
                    type: String
                  },
                  "name" => {
                    description: "The name of the module. Required when `resolve` is `false`.",
                    type: String
                  },
                  "ref" => {
                    description: "The git reference to check out. Can be either a branch, tag, or commit SHA.",
                    type: String
                  },
                  "resolve" => {
                    description: "Whether to resolve the module's dependencies when installing modules.",
                    type: [TrueClass, FalseClass]
                  }
                }
              }
            ]
          },
          _plugin: false,
          _default: [],
          _example: [
            "puppetlabs-facts",
            { "name" => "puppetlabs-mysql" },
            { "name" => "puppetlabs-apache", "version_requirement" => "5.5.0" },
            { "name" => "puppetlabs-puppetdb", "version_requirement" => "7.x" },
            { "name" => "puppetlabs-firewall", "version_requirement" => ">= 1.0.0 < 3.0.0" },
            { "git" => "https://github.com/puppetlabs/puppetlabs-apt", "ref" => "7.6.0" }
          ]
        },
        "name" => {
          description: "The name of the Bolt project. When this option is configured, the project is considered a "\
                       "[Bolt project](projects.md), allowing Bolt to load content from the project directory "\
                       "as though it were a module.",
          type: String,
          _plugin: false,
          _example: "myproject"
        },
        "plans" => {
          description: "A list of plan names and glob patterns to filter the project's plans by. This option is used "\
                       "to limit the visibility of plans for users of the project. For example, project authors "\
                       "might want to limit the visibility of plans that are bundled with Bolt or plans that should "\
                       "only be run as part of another plan. When this option is not configured, all plans are "\
                       "visible. This option does not prevent users from running plans that are not part of this "\
                       "list.",
          type: Array,
          _plugin: false,
          _example: ["myproject", "myproject::foo", "myproject::bar", "myproject::deploy::*"]
        },
        "plugin-hooks" => {
          description: "A map of [plugin hooks](writing_plugins.md#hooks) and which plugins a hook should use. "\
                       "The only configurable plugin hook is `puppet_library`, which can use two possible plugins: "\
                       "[`puppet_agent`](https://github.com/puppetlabs/puppetlabs-puppet_agent#puppet_agentinstall) "\
                       "and [`task`](using_plugins.md#task).",
          type: Hash,
          _plugin: true,
          _example: { "puppet_library" => { "plugin" => "puppet_agent", "version" => "6.15.0", "_run_as" => "root" } }
        },
        "plugins" => {
          description: "A map of plugins and their configuration data, where each key is the name of a plugin and "\
                       "its value is a map of configuration data. Configurable options are specified by the plugin. "\
                       "Read more about configuring plugins in [Using plugins](using_plugins.md#configuring-plugins).",
          type: Hash,
          additionalProperties: {
            type: Hash,
            _plugin: true
          },
          _plugin: false,
          _example: { "pkcs7" => { "keysize" => 1024 } }
        },
        "policies" => {
          description: "A list of policy names and glob patterns to filter the project's policies by. This option "\
                       "is used to specify which policies are available to a project and can be applied to targets. "\
                       "When this option is not configured, policies are not available to the project and cannot "\
                       "be applied to targets.",
          type: Array,
          _plugin: false,
          _example: ["myproject::apache", "myproject::postgres"]
        },
        "puppetdb" => {
          description: "A map containing options for [configuring the Bolt PuppetDB "\
                       "client](bolt_connect_puppetdb.md).",
          type: Hash,
          properties: {
            "cacert" => {
              description: "The path to the ca certificate for PuppetDB.",
              type: String,
              _example: "/etc/puppetlabs/puppet/ssl/certs/ca.pem",
              _plugin: true
            },
            "cert" => {
              description: "The path to the client certificate file to use for authentication.",
              type: String,
              _example: "/etc/puppetlabs/puppet/ssl/certs/my-host.example.com.pem",
              _plugin: true
            },
            "connect_timeout" => {
              description: "How long to wait in seconds when establishing connections with PuppetDB.",
              type: Integer,
              minimum: 1,
              _default: 60,
              _example: 120,
              _plugin: true
            },
            "key" => {
              description: "The private key for the certificate.",
              type: String,
              _example: "/etc/puppetlabs/puppet/ssl/private_keys/my-host.example.com.pem",
              _plugin: true
            },
            "read_timeout" => {
              description: "How long to wait in seconds for a response from PuppetDB.",
              type: Integer,
              minimum: 1,
              _default: 60,
              _example: 120,
              _plugin: true
            },
            "server_urls" => {
              description: "An array containing the PuppetDB host to connect to. Include the protocol `https` "\
                           "and the port, which is usually `8081`. For example, "\
                           "`https://my-puppetdb-server.com:8081`.",
              type: Array,
              _example: ["https://puppet.example.com:8081"],
              _plugin: true
            },
            "token" => {
              description: "The path to the PE RBAC Token.",
              type: String,
              _example: "~/.puppetlabs/token",
              _plugin: true
            }
          },
          _plugin: true
        },
        "save-rerun" => {
          description: "Whether to update `.rerun.json` in the Bolt project directory. If "\
                       "your target names include passwords, set this value to `false` to avoid "\
                       "writing passwords to disk.",
          type: [TrueClass, FalseClass],
          _plugin: false,
          _example: false,
          _default: true
        },
        "spinner" => {
          description: "Whether to print a spinner to the console for long-running Bolt operations.",
          type: [TrueClass, FalseClass],
          _plugin: false,
          _example: false,
          _default: true
        },
        "stream" => {
          description: "Whether to stream output from scripts and commands to the console. "\
                       "**This option is experimental**.",
          type: [TrueClass, FalseClass],
          _plugin: false,
          _default: false,
          _example: true
        },
        "tasks" => {
          description: "A list of task names and glob patterns to filter the project's tasks by. This option is used "\
                       "to limit the visibility of tasks for users of the project. For example, project authors "\
                       "might want to limit the visibility of tasks that are bundled with Bolt or plans that should "\
                       "only be run as part of a larger workflow. When this option is not configured, all tasks "\
                       "are visible. This option does not prevent users from running tasks that are not part of "\
                       "this list.",
          type: Array,
          items: {
            type: String
          },
          _plugin: false,
          _example: ["myproject", "myproject::foo", "myproject::bar", "myproject::deploy_*"]
        },
        "trusted-external-command" => {
          description: "The path to an executable on the Bolt controller that can produce external trusted facts. "\
                       "**External trusted facts are experimental in both Puppet and Bolt and this API might "\
                       "change or be removed.**",
          type: String,
          _plugin: false,
          _example: "/etc/puppetlabs/facts/trusted_external.sh"
        }
      }.freeze

      # Options that configure the inventory, specifically the default transport
      # used by targets and the transports themselves. These options are used in
      # bolt-defaults.yaml under 'inventory-config' and in inventory.yaml under
      # 'config'.
      INVENTORY_OPTIONS = {
        "transport" => {
          description: "The default transport to use when the transport for a target is not "\
                       "specified in the URI.",
          type: String,
          enum: TRANSPORT_CONFIG.keys,
          _plugin: true,
          _example: "winrm",
          _default: "ssh"
        },
        "docker" => {
          description: "A map of configuration options for the docker transport.",
          type: Hash,
          _plugin: true,
          _example: { "cleanup" => false, "service-url" => "https://docker.example.com" }
        },
        "local" => {
          description: "A map of configuration options for the local transport. The set of available options is "\
                       "platform dependent.",
          type: Hash,
          _plugin: true,
          _example: { "cleanup" => false, "tmpdir" => "/tmp/bolt" }
        },
        "lxd" => {
          description: "A map of configuration options for the LXD transport. The LXD transport is "\
                       "experimental and might include breaking changes between minor versions.",
          type: Hash,
          _plugin: true,
          _example: { cleanup: false }
        },
        "pcp" => {
          description: "A map of configuration options for the pcp transport.",
          type: Hash,
          _plugin: true,
          _example: { "job-poll-interval" => 15, "job-poll-timeout" => 30 }
        },
        "podman" => {
          description: "A map of configuration options for the podman transport.",
          type: Hash,
          _plugin: true,
          _example: { "cleanup" => false, "tmpdir" => "/mount/tmp" }
        },
        "remote" => {
          description: "A map of configuration options for the remote transport.",
          type: Hash,
          additionalProperties: true,
          _plugin: true,
          _example: { "run-on" => "proxy_target" }
        },
        "ssh" => {
          description: "A map of configuration options for the ssh transport.",
          type: Hash,
          _plugin: true,
          _example: { "password" => "hunter2!", "user" => "bolt" }
        },
        "winrm" => {
          description: "A map of configuration options for the winrm transport.",
          type: Hash,
          _plugin: true,
          _example: { "password" => "hunter2!", "user" => "bolt" }
        }
      }.freeze

      # Options that are available on the command line
      # This only includes options where users can provide arbitrary
      # values from the command-line, allowing the validator to check them
      CLI_OPTIONS = %w[
        compile-concurrency
        concurrency
        format
        log
        modulepath
        transport
      ].freeze

      # Options that are available in a bolt-defaults.yaml file
      DEFAULTS_OPTIONS = %w[
        analytics
        color
        compile-concurrency
        concurrency
        disable-warnings
        format
        inventory-config
        log
        module-install
        plugin-cache
        plugin-hooks
        plugins
        puppetdb
        save-rerun
        spinner
        stream
      ].freeze

      # Options that are available in a bolt-project.yaml file
      PROJECT_OPTIONS = %w[
        analytics
        apply-settings
        color
        compile-concurrency
        concurrency
        disable-warnings
        format
        future
        hiera-config
        log
        modulepath
        module-install
        modules
        name
        plans
        plugin-cache
        plugin-hooks
        plugins
        policies
        puppetdb
        save-rerun
        spinner
        stream
        tasks
        trusted-external-command
      ].freeze
    end
  end
end
