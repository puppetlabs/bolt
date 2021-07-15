# frozen_string_literal: true

module Bolt
  class Config
    module Transport
      module Options
        LOGIN_SHELLS = %w[sh bash zsh dash ksh powershell].freeze

        # Definitions used to validate config options.
        # https://github.com/puppetlabs/bolt/blob/main/schemas/README.md
        TRANSPORT_OPTIONS = {
          "basic-auth-only" => {
            type: [TrueClass, FalseClass],
            description: "Whether to force basic authentication. This option is only available when using SSL.",
            _plugin: true,
            _default: false,
            _example: true
          },
          "batch-mode" => {
            type: [TrueClass, FalseClass],
            description: "Whether to disable password querying. When set to `false`, SSH will fall back to "\
                         "prompting for a password if key authentication fails. This might cause Bolt to hang. "\
                         "To prevent Bolt from hanging, you can configure `ssh-command` to use an SSH utility "\
                         "such as sshpass that supports providing a password non-interactively. For more "\
                         "information, see [Providing a password non-interactively using "\
                         "`native-ssh`](troubleshooting.md#providing-a-password-non-interactively-using-native-ssh).",
            _plugin: true,
            _default: true,
            _example: false
          },
          "bundled-ruby" => {
            description: "Whether to use the Ruby bundled with Bolt packages for local targets.",
            type: [TrueClass, FalseClass],
            _plugin: false,
            _example: true,
            _default: true
          },
          "cacert" => {
            type: String,
            description: "The path to the CA certificate.",
            _plugin: true,
            _example: "~/.puppetlabs/puppet/cert.pem"
          },
          "cleanup" => {
            type: [TrueClass, FalseClass],
            description: "Whether to clean up temporary files created on targets. When running commands on a target, "\
                         "Bolt might create temporary files. After completing the command, these files are "\
                         "automatically deleted. This value can be set to 'false' if you wish to leave these "\
                         "temporary files on the target.",
            _plugin: true,
            _default: true,
            _example: false
          },
          "connect-timeout" => {
            type: Integer,
            description: "How long to wait in seconds when establishing connections. Set this value higher if you "\
                         "frequently encounter connection timeout errors when running Bolt.",
            minimum: 1,
            _plugin: true,
            _default: 10,
            _example: 15
          },
          "copy-command" => {
            type: [Array, String],
            description: "The command to use when copying files using native SSH. Bolt runs `<copy-command> <src> "\
                         "<dest>`. This option is used when you need support for features or algorithms that are not "\
                         "supported by the net-ssh Ruby library. **This option is experimental.** You can read more "\
                         "about this option in [Native SSH transport](experimental_features.md#native-ssh-transport).",
            items: {
              type: String
            },
            _plugin: true,
            _default: %w[scp -r],
            _example: %w[scp -r -F ~/ssh-config/myconf]
          },
          "disconnect-timeout" => {
            type: Integer,
            description: "How long to wait in seconds before force-closing a connection.",
            minimum: 1,
            _plugin: true,
            _default: 5,
            _example: 10
          },
          "encryption-algorithms" => {
            type: Array,
            description: "A list of encryption algorithms to use when establishing a connection "\
                         "to a target. Supported algorithms are defined by the Ruby net-ssh library and can be "\
                         "viewed [here](https://github.com/net-ssh/net-ssh#supported-algorithms). All supported, "\
                         "non-deprecated algorithms are available by default when this option is not used. To "\
                         "reference all default algorithms using this option, add 'defaults' to the list of "\
                         "supported algorithms.",
            uniqueItems: true,
            items: {
              type: String
            },
            _plugin: true,
            _example: %w[defaults idea-cbc]
          },
          "extensions" => {
            type: Array,
            description: "A list of file extensions that are accepted for scripts or tasks on "\
                         "Windows. Scripts with these file extensions rely on the target's file "\
                         "type association to run. For example, if Python is installed on the "\
                         "system, a `.py` script runs with `python.exe`. The extensions `.ps1`, "\
                         "`.rb`, and `.pp` are always allowed and run via hard-coded "\
                         "executables.",
            uniqueItems: true,
            items: {
              type: String
            },
            _plugin: true,
            _example: [".sh"]
          },
          "file-protocol" => {
            type: String,
            description: "Which file transfer protocol to use. Either `winrm` or `smb`. Using `smb` is "\
                         "recommended for large file transfers.",
            enum: %w[smb winrm],
            _plugin: true,
            _default: "winrm",
            _example: "smb"
          },
          "host" => {
            type: String,
            description: "The target's hostname.",
            _plugin: true,
            _example: "docker_host_production"
          },
          "host-key-algorithms" => {
            type: Array,
            description: "A list of host key algorithms to use when establishing a connection "\
                         "to a target. Supported algorithms are defined by the Ruby net-ssh library and can be "\
                         "viewed [here](https://github.com/net-ssh/net-ssh#supported-algorithms). All supported, "\
                         "non-deprecated algorithms are available by default when this option is not used. To "\
                         "reference all default algorithms using this option, add 'defaults' to the list of "\
                         "supported algorithms.",
            uniqueItems: true,
            items: {
              type: String
            },
            _plugin: true,
            _example: %w[defaults ssh-dss]
          },
          "host-key-check" => {
            type: [TrueClass, FalseClass],
            description: "Whether to perform host key validation when connecting.",
            _plugin: true,
            _example: false
          },
          "interpreters" => {
            type: Hash,
            description: "A map of an extension name to the absolute path of an executable,  enabling you to "\
                         "override the shebang defined in a task executable. The extension can optionally be "\
                         "specified with the `.` character (`.py` and `py` both map to a task executable "\
                         "`task.py`) and the extension is case sensitive. When a target's name is `localhost`, "\
                         "Ruby tasks run with the Bolt Ruby interpreter by default.",
            additionalProperties: {
              type: String,
              _plugin: false
            },
            propertyNames: {
              pattern: "^.?[a-zA-Z0-9]+$"
            },
            _plugin: true,
            _example: { "rb" => "/usr/bin/ruby" }
          },
          "job-poll-interval" => {
            type: Integer,
            description: "The interval, in seconds, to poll orchestrator for job status.",
            minimum: 1,
            _plugin: true,
            _example: 2
          },
          "job-poll-timeout" => {
            type: Integer,
            description: "The time, in seconds, to wait for orchestrator job status.",
            minimum: 1,
            _plugin: true,
            _example: 2000
          },
          "kex-algorithms" => {
            type: Array,
            description: "A list of key exchange algorithms to use when establishing a connection "\
                         "to a target. Supported algorithms are defined by the Ruby net-ssh library and can be "\
                         "viewed [here](https://github.com/net-ssh/net-ssh#supported-algorithms). All supported, "\
                         "non-deprecated algorithms are available by default when this option is not used. To "\
                         "reference all default algorithms using this option, add 'defaults' to the list of "\
                         "supported algorithms.",
            uniqueItems: true,
            items: {
              type: String
            },
            _plugin: true,
            _example: %w[defaults diffie-hellman-group1-sha1]
          },
          "load-config" => {
            type: [TrueClass, FalseClass],
            description: "Whether to load system SSH configuration from '~/.ssh/config' and '/etc/ssh_config'.",
            _plugin: true,
            _default: true,
            _example: false
          },
          "login-shell" => {
            type: String,
            description: "Which login shell Bolt should expect on the target. Supported shells are " \
                         "#{LOGIN_SHELLS.join(', ')}. **This option is experimental.**",
            enum: LOGIN_SHELLS,
            _plugin: true,
            _default: "bash",
            _example: "powershell"
          },
          "mac-algorithms" => {
            type: Array,
            description: "List of message authentication code algorithms to use when establishing a connection "\
                         "to a target. Supported algorithms are defined by the Ruby net-ssh library and can be "\
                         "viewed [here](https://github.com/net-ssh/net-ssh#supported-algorithms). All supported, "\
                         "non-deprecated algorithms are available by default when this option is not used. To "\
                         "reference all default algorithms using this option, add 'defaults' to the list of "\
                         "supported algorithms.",
            uniqueItems: true,
            items: {
              type: String
            },
            _plugin: true,
            _example: %w[defaults hmac-md5]
          },
          "native-ssh" => {
            type: [TrueClass, FalseClass],
            description: "This enables the native SSH transport, which shells out to SSH instead of using the "\
                         "net-ssh Ruby library",
            _default: false,
            _example: true
          },
          "password" => {
            type: String,
            description: "The password to use to login.",
            _plugin: true,
            _example: "hunter2!"
          },
          "port" => {
            type: Integer,
            description: "The port to use when connecting to the target.",
            minimum: 0,
            _plugin: true,
            _example: 22
          },
          "private-key" => {
            type: [Hash, String],
            description: "Either the path to the private key file to use for authentication, or "\
            "a hash with the key `key-data` and the contents of the private key. Note that "\
            "the key cannot be encrypted if using the `key-data` hash.",
            required: ["key-data"],
            properties: {
              "key-data" => {
                description: "The contents of the private key.",
                type: String
              }
            },
            _plugin: true,
            _example: "~/.ssh/id_rsa"
          },
          "proxyjump" => {
            type: String,
            description: "A jump host to proxy connections through, and an optional user to connect with.",
            format: "uri",
            _plugin: true,
            _example: "jump.example.com"
          },
          "read-timeout" => {
            type: Integer,
            description: "How long to wait in seconds when making requests to the Orchestrator.",
            minimum: 1,
            _plugin: true,
            _example: 15
          },
          "realm" => {
            type: String,
            description: "The Kerberos realm (Active Directory domain) to authenticate against.",
            _plugin: true,
            _example: "BOLT.PRODUCTION"
          },
          "remote" => {
            type: String,
            description: "The LXD remote host to use.",
            _default: "local",
            _plugin: false,
            _example: 'myremote'
          },
          "run-as" => {
            type: String,
            description: "The user to run commands as after login. The run-as user must be different than the "\
                         "login user.",
            _plugin: true,
            _example: "root"
          },
          "run-as-command" => {
            type: Array,
            description: "The command to elevate permissions. Bolt appends the user and command strings to the "\
                         "configured `run-as-command` before running it on the target. This command must not require "\
                         " aninteractive password prompt, and the `sudo-password` option is ignored when "\
                         "`run-as-command` is specified. The `run-as-command` must be specified as an array.",
            items: {
              type: String
            },
            _plugin: true,
            _example: ["sudo", "-nkSEu"]
          },
          "run-on" => {
            type: String,
            description: "The proxy target that the task executes on.",
            format: "uri",
            _plugin: true,
            _default: "localhost",
            _example: "proxy_target"
          },
          "script-dir" => {
            type: String,
            description: "The subdirectory of the tmpdir to use in place of a randomized "\
                         "subdirectory for uploading and executing temporary files on the "\
                         "target. It's expected that this directory already exists as a subdir "\
                         "of tmpdir, which is either configured or defaults to `/tmp`.",
            _plugin: true,
            _example: "bolt_scripts"
          },
          "service-url" => {
            type: String,
            description: "The URL of the host used for API requests.",
            format: "uri",
            _plugin: true,
            _example: "https://api.example.com:8143"
          },
          "shell-command" => {
            type: String,
            description: "A shell command to wrap any Docker exec commands in, such as `bash -lc`.",
            _plugin: true,
            _example: "bash -lc"
          },
          "smb-port" => {
            type: Integer,
            description: "The port to use when connecting to the target when file-protocol is set to 'smb'.",
            minimum: 0,
            _plugin: true,
            _example: 445
          },
          "ssh-command" => {
            type: [Array, String],
            description: "The command and options to use when SSHing. This option is used when you need support for "\
                         "features or algorithms that are not supported by the net-ssh Ruby library. **This option "\
                         "is experimental.** You can read more about this  option in [Native SSH "\
                         "transport](experimental_features.md#native-ssh-transport).",
            items: {
              type: String
            },
            _plugin: true,
            _default: 'ssh',
            _example: %w[ssh -o Ciphers=chacha20-poly1305@openssh.com]
          },
          "ssl" => {
            type: [TrueClass, FalseClass],
            description: "Whether to use secure https connections for WinRM.",
            _plugin: true,
            _default: true,
            _example: false
          },
          "ssl-verify" => {
            type: [TrueClass, FalseClass],
            description: "Whether to verify that the target's certificate matches the cacert.",
            _plugin: true,
            _default: true,
            _example: false
          },
          "sudo-executable" => {
            type: String,
            description: "The executable to use when escalating to the configured `run-as` user. This is useful "\
                         "when you want to escalate using the configured `sudo-password`, since `run-as-command` "\
                         "does not use `sudo-password` or support prompting. The command executed on the target "\
                         "is `<sudo-executable> -S -u <user> -p custom_bolt_prompt <command>`. **This option is "\
                         "experimental.**",
            _plugin: true,
            _example: "dzdo"
          },
          "sudo-password" => {
            type: String,
            description: "The password to use when changing users via `run-as`.",
            _plugin: true,
            _example: "p@$$w0rd!"
          },
          "task-environment" => {
            type: String,
            description: "The environment the orchestrator loads task code from.",
            _plugin: true,
            _default: "production",
            _example: "development"
          },
          "tmpdir" => {
            type: String,
            description: "The directory to upload and execute temporary files on the target.",
            _plugin: true,
            _example: "/tmp/bolt"
          },
          "token-file" => {
            type: String,
            description: "The path to the token file.",
            _plugin: true,
            _example: "~/.puppetlabs/puppet/token.pem"
          },
          "tty" => {
            type: [TrueClass, FalseClass],
            description: "Whether to enable tty on exec commands.",
            _plugin: true,
            _example: true
          },
          "user" => {
            type: String,
            description: "The user name to login as.",
            _plugin: true,
            _example: "bolt"
          }
        }.freeze

        RUN_AS_OPTIONS = %w[
          run-as
          run-as-command
          sudo-executable
          sudo-password
        ].freeze
      end
    end
  end
end
