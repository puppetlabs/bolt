# frozen_string_literal: true

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

      root_logger = Logging.logger[:root]
      root_logger.add_appenders Logging.appenders.stderr(
        'console',
        layout: default_layout,
        level: default_level
      )
      # We set the root logger's level so that it logs everything but we do
      # limit what's actually logged in every appender individually.
      root_logger.level = :all
    end

    def self.configure(config)
      root_logger = Logging.logger[:root]

      config[:log].each_pair do |name, params|
        appender = Logging.appenders[name]
        if appender.nil?
          unless name.start_with?('file:')
            raise Bolt::Error.new("Unexpected log: #{name}", 'bolt/internal-error')
          end

          begin
            appender = Logging.appenders.file(
              name,
              filename: name[5..-1], # strip the "file:" prefix
              truncate: (params[:append] == false),
              layout: default_layout,
              level: default_level
            )
          rescue ArgumentError => e
            raise Bolt::CLIError, "Failed to open log #{name}: #{e.message}"
          end

          root_logger.add_appenders appender
        end

        appender.level = params[:level] if params[:level]
      end
    end

    def self.default_layout
      @default_layout ||= Logging.layouts.pattern(
        pattern: '%d %-6l %c: %m\n',
        date_pattern: '%Y-%m-%dT%H:%M:%S.%6N'
      )
    end

    def self.default_level
      :notice
    end

    def self.valid_level?(level)
      !Logging.level_num(level).nil?
    end

    def self.levels
      Logging::LNAMES.map(&:downcase)
    end

    def self.reset_logging
      Logging.reset
    end
  end
end
