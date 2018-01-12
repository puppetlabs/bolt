require 'logging'

module Bolt
  module Logger
    # This method provides a single point-of-entry to setup logging for both
    # the CLI and for tests. This is necessary because we define custom log
    # levels which create corresponding methods on the logger instances;
    # without first initializing the Logging system, calls to those methods
    # will fail.
    def self.initialize_logging
      # Initialization isn't idempotent and will result in warnings about const
      # redefs, so skip it if it's already been initialized
      return if Logging.initialized?

      Logging.init :debug, :info, :notice, :warn, :error, :fatal, :any
      Logging.appenders.stderr(
        'stderr',
        layout: Logging.layouts.pattern(
          pattern: '%d %-6l %c: %m\n',
          date_pattern: '%Y-%m-%dT%H:%M:%S.%6N'
        )
      )
      root_logger = Logging.logger[:root]
      root_logger.add_appenders :stderr
      root_logger.level = :notice
    end

    def self.reset_logging
      Logging.reset
    end
  end
end
