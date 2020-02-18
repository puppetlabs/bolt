# frozen_string_literal: true

require 'bolt/error'
require 'bolt/config/transport'

module Bolt
  class Config
    class Docker < Transport
      OPTIONS = {
        "host"          => "Host name.",
        "interpreters"  => "A map of an extension name to the absolute path of an executable, "\
                            "enabling you to override the shebang defined in a task executable. The "\
                            "extension can optionally be specified with the `.` character (`.py` and "\
                            "`py` both map to a task executable `task.py`) and the extension is case "\
                            "sensitive. When a target's name is `localhost`, Ruby tasks run with the "\
                            "Bolt Ruby interpreter by default.",
        "service-url"   => "URL of the Docker host used for API requests.",
        "shell-command" => "A shell command to wrap any Docker exec commands in, such as `bash -lc`.",
        "tmpdir"        => "The directory to upload and execute temporary files on the target.",
        "tty"           => "Whether to enable tty on exec commands."
      }.freeze

      DEFAULTS = {}.freeze

      private def validate
        validate_boolean('tty')
        validate_type(String, 'host', 'service-url', 'shell-command', 'tmpdir')
        validate_type(Hash, 'interpreters')

        if config['interpreters']
          @config['interpreters'] = normalize_interpreters(config['interpreters'])
        end
      end
    end
  end
end
