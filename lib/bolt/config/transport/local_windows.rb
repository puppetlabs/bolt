# frozen_string_literal: true

require 'bolt/error'
require 'bolt/config/transport'

module Bolt
  class Config
    class LocalWindows < Transport
      OPTIONS = {
        "interpreters" => "A map of an extension name to the absolute path of an executable, "\
                            "enabling you to override the shebang defined in a task executable. The "\
                            "extension can optionally be specified with the `.` character (`.py` and "\
                            "`py` both map to a task executable `task.py`) and the extension is case "\
                            "sensitive. When a target's name is `localhost`, Ruby tasks run with the "\
                            "Bolt Ruby interpreter by default.",
        "tmpdir" => "The directory to copy and execute temporary files."
      }.freeze

      DEFAULTS = {}.freeze

      private def validate
        validate_type(String, 'tmpdir')
        validate_type(Hash, 'interpreters')

        if config['interpreters']
          @config['interpreters'] = normalize_interpreters(config['interpreters'])
        end
      end
    end
  end
end
