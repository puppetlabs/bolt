# frozen_string_literal: true

require 'bolt/util/puppet_log_level'

Puppet::Util::Log.newdesttype :logging do
  match "Logging::Logger"

  # Bolt log levels don't match exactly with Puppet log levels, so we use
  # an explicit mapping.
  def initialize(logger)
    @external_logger = logger
  end

  def handle(log)
    @external_logger.send(Bolt::Util::PuppetLogLevel::MAPPING[log.level], log.to_s)
  end
end
