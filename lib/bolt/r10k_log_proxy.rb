# frozen_string_literal: true

require 'log4r/outputter/outputter'

module Bolt
  class R10KLogProxy < Log4r::Outputter
    def initialize
      super('bolt')

      @logger = Logging.logger[self]
    end

    def canonical_log(event)
      level = to_bolt_level(event.level)
      @logger.send(level, event.data)
    end

    # Convert an r10k log level to a bolt log level. These correspond 1-to-1
    # except that r10k has debug, debug1, and debug2. The log event has the log
    # level as an integer that we need to look up.
    def to_bolt_level(level_num)
      level_str = Log4r::LNAMES[level_num]&.downcase || 'debug'
      if level_str =~ /debug/
        :debug
      else
        level_str.to_sym
      end
    end
  end
end
