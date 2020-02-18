# frozen_string_literal: true

require 'bolt/error'
require 'bolt/config/transport/sudoable'

module Bolt
  class Config
    class SSH < Sudoable
      OPTIONS = {
        "connect-timeout"    => "How long to wait when establishing connections.",
        "disconnect-timeout" => "How long to wait before force-closing a connection.",
        "host"               => "Host name.",
        "host-key-check"     => "Whether to perform host key validation when connecting.",
        "interpreters"       => "A map of an extension name to the absolute path of an executable, "\
                                "enabling you to override the shebang defined in a task executable. The "\
                                "extension can optionally be specified with the `.` character (`.py` and "\
                                "`py` both map to a task executable `task.py`) and the extension is case "\
                                "sensitive. When a target's name is `localhost`, Ruby tasks run with the "\
                                "Bolt Ruby interpreter by default.",
        "load-config"        => "Whether to load system SSH configuration.",
        "password"           => "Login password.",
        "port"               => "Connection port.",
        "private-key"        => "Either the path to the private key file to use for authentication, or a "\
                                "hash with the key `key-data` and the contents of the private key.",
        "proxyjump"          => "A jump host to proxy connections through, and an optional user to "\
                                "connect with.",
        "run-as"             => "A different user to run commands as after login.",
        "run-as-command"     => "The command to elevate permissions. Bolt appends the user and command "\
                                "strings to the configured `run-as-command` before running it on the "\
                                "target. This command must not require an interactive password prompt, "\
                                "and the `sudo-password` option is ignored when `run-as-command` is "\
                                "specified. The `run-as-command` must be specified as an array.",
        "script-dir"         => "The subdirectory of the tmpdir to use in place of a randomized "\
                                "subdirectory for uploading and executing temporary files on the "\
                                "target. It's expected that this directory already exists as a subdir "\
                                "of tmpdir, which is either configured or defaults to `/tmp`.",
        "sudo-executable"    => "The executable to use when escalating to the configured `run-as` "\
                                "user. This is useful when you want to escalate using the configured "\
                                "`sudo-password`, since `run-as-command` does not use `sudo-password` "\
                                "or support prompting. The command executed on the target is "\
                                "`<sudo-executable> -S -u <user> -p custom_bolt_prompt <command>`. "\
                                "**This option is experimental.**",
        "sudo-password"      => "Password to use when changing users via `run-as`.",
        "tmpdir"             => "The directory to upload and execute temporary files on the target.",
        "tty"                => "Request a pseudo tty for the session. This option is generally "\
                                "only used in conjunction with the `run-as` option when the sudoers "\
                                "policy requires a `tty`.",
        "user"               => "Login user."
      }.freeze

      DEFAULTS = {
        "connect-timeout"    => 10,
        "tty"                => false,
        "load-config"        => true,
        "disconnect-timeout" => 5
      }.freeze

      private def validate
        super

        validate_boolean('host-key-check', 'load-config', 'tty')
        validate_type(Integer, 'connect-timeout', 'disconnect-timeout')

        validate_type(String, 'host', 'password', 'proxyjump', 'run-as', 'script-dir', 'sudo-executable',
                      'sudo-password', 'tmpdir', 'user')

        validate_type(Hash, 'interpreters')

        if (key_opt = config['private-key'])
          unless key_opt.instance_of?(String) || (key_opt.instance_of?(Hash) && key_opt.include?('key-data'))
            raise Bolt::ValidationError,
                  "private-key option must be a path to a private key file or a Hash containing the 'key-data', "\
                  "received #{key_opt.class} #{key_opt}"
          end

          if key_opt.instance_of?(String)
            @config['private-key'] = File.expand_path(key_opt, @boltdir)
            Bolt::Util.validate_file('private-key', config['private-key'])
          end
        end

        if config['interpreters']
          @config['interpreters'] = normalize_interpreters(config['interpreters'])
        end
      end
    end
  end
end
