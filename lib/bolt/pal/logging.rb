# frozen_string_literal: true

Puppet::Util::Log.newdesttype :logging do
  match "Logging::Logger"

  # Bolt log levels don't match exactly with Puppet log levels, so we use
  # an explicit mapping.
  def initialize(logger)
    @external_logger = logger

    @log_level_map = {
      debug: :debug,
      info: :info,
      notice: :notice,
      warning: :warn,
      err: :error,
      # Nothing in Puppet actually uses alert, emerg or crit, so it's hard to say
      # what they indicate, but they sound pretty bad.
      alert: :error,
      emerg: :fatal,
      crit: :fatal
    }
  end

  def handle(log)
    @external_logger.send(@log_level_map[log.level], log.to_s)
  end
end
