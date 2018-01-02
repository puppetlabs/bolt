require 'logger'

class Logger
  send :remove_const, 'SEV_LABEL'

  SEV_LABEL = {
    0 => 'DEBUG',
    1 => 'INFO',
    2 => 'NOTICE',
    3 => 'WARN',
    4 => 'ERROR',
    5 => 'FATAL',
    6 => 'ANY'
  }.freeze

  module Severity
    levels = %w[WARN ERROR FATAL ANY]
    levels.each do |level|
      send(:remove_const, level) if const_defined?(level)
    end
    NOTICE = 2
    WARN = 3
    ERROR = 4
    FATAL = 5
    ANY = 6
  end

  def notice(progname = nil, &block)
    add(NOTICE, nil, progname, &block)
  end

  def notice?
    @level <= NOTICE
  end

  @@logger = nil
  @@logger_mutex = Mutex.new

  def self.instance(name = nil)
    return @@logger if @@logger
    @@logger_mutex.synchronize {
      return @@logger if @@logger
      @@logger = new(name)
    }
    @@logger
  end
end
