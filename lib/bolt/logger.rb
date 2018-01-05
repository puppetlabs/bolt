require 'logger'
require 'bolt/formatter'

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

  # rubocop:disable Style/ClassVars
  @@config = {
    log_destination: STDERR,
    log_level: NOTICE
  }

  # Not thread safe call only during startup
  def self.configure(config)
    @@config[:log_level] = config[:log_level] if config[:log_level]
  end

  def self.get_logger(**conf)
    conf = @@config.merge(conf)
    logger = new(conf[:log_destination])
    logger.level = conf[:log_level]
    logger.progname = conf[:progname] if conf[:progname]
    logger.formatter = Bolt::Formatter.new
    logger
  end
end
