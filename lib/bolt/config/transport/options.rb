# frozen_string_literal: true

module Bolt
  class Config
    module Transport
      module Options
        LOGIN_SHELLS = %w[sh bash zsh dash ksh powershell].freeze

        # The following constant defines the various configuration options available to Bolt's.
        # transports. Each key is a configuration option and values are the data describing the
        # option. Data includes the following keys:
        #   :def     The **documented** default value. This is the value that is displayed
        #            in the reference docs and is not used by Bolt to actually set a default
        #            value.
        #   :desc    The text description of the option that is displayed in documentation.
        #   :exmp    An example value for the option. This is used to generate an example
        #            configuration file in the reference docs.
        #   :type    The option's expected type. If an option accepts multiple types, this is
        #            an array of the accepted types. Any options that accept a Boolean value
        #            should use the [TrueClass, FalseClass] type.
        #
        # NOTE: All transport configuration options should have a corresponding schema definition
        #       in schemas/bolt-transport-definitions.json
        TRANSPORT_OPTIONS = {
          "basic-auth-only" => {
            type: [TrueClass, FalseClass],
            desc: "Whether to force basic authentication. This option is only available when using SSL.",
            def:  false,
            exmp: true
          },
          "cacert" => {
            type: String,
            desc: "The path to the CA certificate.",
            exmp: "~/.puppetlabs/puppet/cert.pem"
          },
          "cleanup" => {
            type: [TrueClass, FalseClass],
            desc: "Whether to clean up temporary files created on targets. When running commands on a target, "\
                  "Bolt may create temporary files. After completing the command, these files are automatically "\
                  "deleted. This value can be set to 'false' if you wish to leave these temporary files on the "\
                  "target.",
            def:  true,
            exmp: false
          },
          "connect-timeout" => {
            type: Integer,
            desc: "How long to wait in seconds when establishing connections. Set this value higher if you "\
                  "frequently encounter connection timeout errors when running Bolt.",
            def:  10,
            exmp: 15
          },
          "copy-command" => {
            type: [Array, String],
            desc: "The command to use when copying files using ssh-command. Bolt runs `<copy-command> <src> <dest>`. "\
                  "This option is used when you need support for features or algorithms that are not supported "\
                  "by the net-ssh Ruby library. **This option is experimental.** You can read more about this "\
                  "option in [External SSH transport](experimental_features.md#external-ssh-transport).",
            def:  "scp -r",
            exmp: "scp -r -F ~/ssh-config/myconf"
          },
          "disconnect-timeout" => {
            type: Integer,
            desc: "How long to wait in seconds before force-closing a connection.",
            def:  5,
            exmp: 10
          },
          "encryption-algorithms" => {
            type: Array,
            desc: "A list of encryption algorithms to use when establishing a connection "\
                  "to a target. Supported algorithms are defined by the Ruby net-ssh library and can be "\
                  "viewed [here](https://github.com/net-ssh/net-ssh#supported-algorithms). All supported, "\
                  "non-deprecated algorithms are available by default when this option is not used. To "\
                  "reference all default algorithms using this option, add 'defaults' to the list of "\
                  "supported algorithms.",
            exmp: %w[defaults idea-cbc]
          },
          "extensions" => {
            type: Array,
            desc: "A list of file extensions that are accepted for scripts or tasks on "\
                  "Windows. Scripts with these file extensions rely on the target's file "\
                  "type association to run. For example, if Python is installed on the "\
                  "system, a `.py` script runs with `python.exe`. The extensions `.ps1`, "\
                  "`.rb`, and `.pp` are always allowed and run via hard-coded "\
                  "executables.",
            exmp: [".sh"]
          },
          "file-protocol" => {
            type: String,
            desc: "Which file transfer protocol to use. Either `winrm` or `smb`. Using `smb` is "\
                  "recommended for large file transfers.",
            def:  "winrm",
            exmp: "smb"
          },
          "host" => {
            type: String,
            desc: "The target's hostname.",
            exmp: "docker_host_production"
          },
          "host-key-algorithms" => {
            type: Array,
            desc: "A list of host key algorithms to use when establishing a connection "\
                  "to a target. Supported algorithms are defined by the Ruby net-ssh library and can be "\
                  "viewed [here](https://github.com/net-ssh/net-ssh#supported-algorithms). All supported, "\
                  "non-deprecated algorithms are available by default when this option is not used. To "\
                  "reference all default algorithms using this option, add 'defaults' to the list of "\
                  "supported algorithms.",
            exmp: %w[defaults ssh-dss]
          },
          "host-key-check" => {
            type: [TrueClass, FalseClass],
            desc: "Whether to perform host key validation when connecting.",
            exmp: false
          },
          "interpreters" => {
            type: Hash,
            desc: "A map of an extension name to the absolute path of an executable,  enabling you to override "\
                  "the shebang defined in a task executable. The extension can optionally be specified with the "\
                  "`.` character (`.py` and `py` both map to a task executable `task.py`) and the extension is "\
                  "case sensitive. When a target's name is `localhost`, Ruby tasks run with the Bolt Ruby "\
                  "interpreter by default.",
            exmp: { "rb" => "/usr/bin/ruby" }
          },
          "job-poll-interval" => {
            type: Integer,
            desc: "The interval, in seconds, to poll orchestrator for job status.",
            exmp: 2
          },
          "job-poll-timeout" => {
            type: Integer,
            desc: "The time, in seconds, to wait for orchestrator job status.",
            exmp: 2000
          },
          "kex-algorithms" => {
            type: Array,
            desc: "A list of key exchange algorithms to use when establishing a connection "\
                  "to a target. Supported algorithms are defined by the Ruby net-ssh library and can be "\
                  "viewed [here](https://github.com/net-ssh/net-ssh#supported-algorithms). All supported, "\
                  "non-deprecated algorithms are available by default when this option is not used. To "\
                  "reference all default algorithms using this option, add 'defaults' to the list of "\
                  "supported algorithms.",
            exmp: %w[defaults diffie-hellman-group1-sha1]
          },
          "load-config" => {
            type: [TrueClass, FalseClass],
            desc: "Whether to load system SSH configuration from '~/.ssh/config' and '/etc/ssh_config'.",
            def:  true,
            exmp: false
          },
          "login-shell" => {
            type: String,
            desc: "Which login shell Bolt should expect on the target. Supported shells are " \
                  "#{LOGIN_SHELLS.join(', ')}. **This option is experimental.**",
            def:  "bash",
            exmp: "powershell"
          },
          "mac-algorithms" => {
            type: Array,
            desc: "List of message authentication code algorithms to use when establishing a connection "\
                  "to a target. Supported algorithms are defined by the Ruby net-ssh library and can be "\
                  "viewed [here](https://github.com/net-ssh/net-ssh#supported-algorithms). All supported, "\
                  "non-deprecated algorithms are available by default when this option is not used. To "\
                  "reference all default algorithms using this option, add 'defaults' to the list of "\
                  "supported algorithms.",
            exmp: %w[defaults hmac-md5]
          },
          "password" => {
            type: String,
            desc: "The password to use to login.",
            exmp: "hunter2!"
          },
          "port" => {
            type: Integer,
            desc: "The port to use when connecting to the target.",
            exmp: 22
          },
          "private-key" => {
            type: [Hash, String],
            desc: "Either the path to the private key file to use for authentication, or "\
                  "a hash with the key `key-data` and the contents of the private key.",
            exmp: "~/.ssh/id_rsa"
          },
          "proxyjump" => {
            type: String,
            desc: "A jump host to proxy connections through, and an optional user to connect with.",
            exmp: "jump.example.com"
          },
          "realm" => {
            type: String,
            desc: "The Kerberos realm (Active Directory domain) to authenticate against.",
            exmp: "BOLT.PRODUCTION"
          },
          "run-as" => {
            type: String,
            desc: "The user to run commands as after login. The run-as user must be different than the login user.",
            exmp: "root"
          },
          "run-as-command" => {
            type: Array,
            desc: "The command to elevate permissions. Bolt appends the user and command strings to the configured "\
                  "`run-as-command` before running it on the target. This command must not require an interactive "\
                  "password prompt, and the `sudo-password` option is ignored when `run-as-command` is specified. "\
                  "The `run-as-command` must be specified as an array.",
            exmp: ["sudo", "-nkSEu"]
          },
          "run-on" => {
            type: String,
            desc: "The proxy target that the task executes on.",
            def:  "localhost",
            exmp: "proxy_target"
          },
          "script-dir" => {
            type: String,
            desc: "The subdirectory of the tmpdir to use in place of a randomized "\
                  "subdirectory for uploading and executing temporary files on the "\
                  "target. It's expected that this directory already exists as a subdir "\
                  "of tmpdir, which is either configured or defaults to `/tmp`.",
            exmp: "bolt_scripts"
          },
          "service-url" => {
            type: String,
            desc: "The URL of the host used for API requests.",
            exmp: "https://api.example.com"
          },
          "shell-command" => {
            type: String,
            desc: "A shell command to wrap any Docker exec commands in, such as `bash -lc`.",
            exmp: "bash -lc"
          },
          "smb-port" => {
            type: Integer,
            desc: "The port to use when connecting to the target when file-protocol is set to 'smb'.",
            exmp: 445
          },
          "ssh-command" => {
            type: [Array, String],
            desc: "The command and flags to use when SSHing. This enables the external SSH transport, which "\
                  "shells out to the specified command. This option is used when you need support for "\
                  "features or algorithms that are not supported by the net-ssh Ruby library. **This option is "\
                  "experimental.** You can read more about this  option in [External SSH "\
                  "transport](experimental_features.md#external-ssh-transport).",
            exmp: "ssh"
          },
          "ssl" => {
            type: [TrueClass, FalseClass],
            desc: "Whether to use secure https connections for WinRM.",
            def:  true,
            exmp: false
          },
          "ssl-verify" => {
            type: [TrueClass, FalseClass],
            desc: "Whether to verify that the target's certificate matches the cacert.",
            def:  true,
            exmp: false
          },
          "sudo-executable" => {
            type: String,
            desc: "The executable to use when escalating to the configured `run-as` user. This is useful when you "\
                  "want to escalate using the configured `sudo-password`, since `run-as-command` does not use "\
                  "`sudo-password` or support prompting. The command executed on the target is `<sudo-executable> "\
                  "-S -u <user> -p custom_bolt_prompt <command>`. **This option is experimental.**",
            exmp: "dzdo"
          },
          "sudo-password" => {
            type: String,
            desc: "The password to use when changing users via `run-as`.",
            exmp: "p@$$w0rd!"
          },
          "task-environment" => {
            type: String,
            desc: "The environment the orchestrator loads task code from.",
            def:  "production",
            exmp: "development"
          },
          "tmpdir" => {
            type: String,
            desc: "The directory to upload and execute temporary files on the target.",
            exmp: "/tmp/bolt"
          },
          "token-file" => {
            type: String,
            desc: "The path to the token file.",
            exmp: "~/.puppetlabs/puppet/token.pem"
          },
          "tty" => {
            type: [TrueClass, FalseClass],
            desc: "Whether to enable tty on exec commands.",
            exmp: true
          },
          "user" => {
            type: String,
            desc: "The user name to login as.",
            exmp: "bolt"
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
