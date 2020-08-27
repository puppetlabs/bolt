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

      Logging.init :trace, :debug, :info, :notice, :warn, :error, :fatal, :any
      @mutex = Mutex.new

      Logging.color_scheme(
        'bolt',
        lines: {
          warn: :yellow,
          error: :red,
          fatal: %i[white on_red]
        }
      )
    end

    def self.configure(destinations, color)
      root_logger = Bolt::Logger.logger(:root)

      root_logger.add_appenders Logging.appenders.stderr(
        'console',
        layout: console_layout(color),
        level: default_console_level
      )

      # We set the root logger's level so that it logs everything but we do
      # limit what's actually logged in every appender individually.
      root_logger.level = :all

      destinations.each_pair do |name, params|
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
              level: default_file_level
            )
          rescue ArgumentError => e
            raise Bolt::Error.new("Failed to open log #{name}: #{e.message}", 'bolt/log-error')
          end

          root_logger.add_appenders appender
        end

        appender.level = params[:level] if params[:level]
      end
    end

    # A helper to ensure the Logging library is always initialized with our
    # custom log levels before retrieving a Logger instance.
    def self.logger(name)
      initialize_logging
      Logging.logger[name]
    end

    def self.analytics=(analytics)
      @analytics = analytics
    end

    def self.console_layout(color)
      color_scheme = :bolt if color
      Logging.layouts.pattern(
        pattern: '%m\e[0m\n',
        color_scheme: color_scheme
      )
    end

    def self.default_layout
      Logging.layouts.pattern(
        pattern: '%d %-6l [%T] [%c] %m\n',
        date_pattern: '%Y-%m-%dT%H:%M:%S.%6N'
      )
    end

    def self.default_console_level
      :warn
    end

    def self.default_file_level
      :warn
    end

    # Explicitly check the log level names instead of the log level number, as levels
    # that are stringified integers (e.g. "level" => "42") will return a truthy value
    def self.valid_level?(level)
      Logging::LEVELS.include?(Logging.levelify(level))
    end

    def self.levels
      Logging::LNAMES.map(&:downcase)
    end

    def self.reset_logging
      Logging.reset
    end

    def self.warn_once(type, msg)
      @mutex.synchronize {
        @warnings ||= []
        @logger ||= Bolt::Logger.logger(self)
        unless @warnings.include?(type)
          @logger.warn(msg)
          @warnings << type
        end
      }
    end

    def self.deprecation_warning(type, msg)
      @analytics&.event('Warn', 'deprecation', label: type)
      warn_once(type, msg)
    end
  end
end
