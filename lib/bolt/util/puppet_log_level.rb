# frozen_string_literal: true

module Bolt
  module Util
    module PuppetLogLevel
      MAPPING = {
        debug: :debug,
        info: :info,
        notice: :notice,
        warning: :warn,
        err: :error,
        # The following are used by Puppet functions of the same name, and are all treated as
        # error types in the Windows EventLog and log colors.
        alert: :error,
        emerg: :fatal,
        crit: :fatal
      }.freeze
    end
  end
end
