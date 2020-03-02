# frozen_string_literal: true

require 'bolt/error'
require 'bolt/config/transport'

module Bolt
  class Config
    class Local < Sudoable
      OPTIONS = {
        "interpreters"    => { type: Hash,
                               desc: "A map of an extension name to the absolute path of an executable, "\
                                     "enabling you to override the shebang defined in a task executable. The "\
                                     "extension can optionally be specified with the `.` character (`.py` and "\
                                     "`py` both map to a task executable `task.py`) and the extension is case "\
                                     "sensitive. When a target's name is `localhost`, Ruby tasks run with the "\
                                     "Bolt Ruby interpreter by default." },
        "run-as"          => { type: String,
                               desc: "A different user to run commands as after login." },
        "run-as-command"  => { desc: "The command to elevate permissions. Bolt appends the user and command "\
                                     "strings to the configured `run-as-command` before running it on the target. "\
                                     "This command must not require an interactive password prompt, and the "\
                                     "`sudo-password` option is ignored when `run-as-command` is specified. The "\
                                     "`run-as-command` must be specified as an array." },
        "sudo-executable" => { type: String,
                               desc: "The executable to use when escalating to the configured `run-as` user. This "\
                                     "is useful when you want to escalate using the configured `sudo-password`, since "\
                                     "`run-as-command` does not use `sudo-password` or support prompting. The command "\
                                     "executed on the target is `<sudo-executable> -S -u <user> -p custom_bolt_prompt "\
                                     "<command>`. **This option is experimental.**" },
        "sudo-password"   => { type: String,
                               desc: "Password to use when changing users via `run-as`." },
        "tmpdir"          => { type: String,
                               desc: "The directory to copy and execute temporary files." }
      }.freeze

      DEFAULTS = {}.freeze

      private def validate
        super

        assert_type

        if config['interpreters']
          @config['interpreters'] = normalize_interpreters(config['interpreters'])
        end
      end
    end
  end
end
