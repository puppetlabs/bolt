# frozen_string_literal: true

require 'logging'

module Bolt
  module Logger
    LEVELS = %w[trace debug info warn error fatal].freeze

    # This module is treated as a global singleton so that multiple classes
    # in Bolt can log warnings with IDs. Access to the following variables
    # are controlled by a mutex.
    @mutex            = Mutex.new
    @warnings         = Set.new
    @disable_warnings = Set.new
    @message_queue    = []

    # This method provides a single point-of-entry to setup logging for both
    # the CLI and for tests. This is necessary because we define custom log
    # levels which create corresponding methods on the logger instances;
    # without first initializing the Logging system, calls to those methods
    # will fail.
    def self.initialize_logging
      # Initialization isn't idempotent and will result in warnings about const
      # redefs, so skip it if the log levels we expect are present. If it's
      # already been initialized with an insufficient set of levels, go ahead
      # and call init anyway or we'll have failures when calling log methods
      # for missing levels.
      unless levels & LEVELS == LEVELS
        Logging.init(*LEVELS)
      end

      # As above, only create the color scheme if we haven't already created it.
      unless Logging.color_scheme('bolt')
        Logging.color_scheme(
          'bolt',
          lines: {
            warn: :yellow,
            error: :red,
            fatal: %i[white on_red]
          }
        )
      end
    end

    def self.configure(destinations, color, disable_warnings = nil)
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

      # Set the list of disabled warnings and mark the logger as configured.
      # Log all messages in the message queue and flush the queue.
      if disable_warnings
        @mutex.synchronize { @disable_warnings = disable_warnings }
      end
    end

    def self.configured?
      Logging.logger[:root].appenders.any?
    end

    def self.stream
      @stream
    end

    def self.stream=(stream)
      @stream = stream
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

    # Checks if the specified level logs to the console.
    #
    def self.log_to_console?(level)
      configured? && console_level <= Logging.level_num(level)
    end

    # Returns the log level for the console.
    #
    def self.console_level
      Logging.logger[:root].appenders.select { |appender| appender.name == 'console' }.first&.level
    end

    # The following methods are used in place of the Logging.logger
    # methods of the same name when logging warning messages or logging
    # any messages prior to the logger being configured. If the logger
    # is not configured when any of these methods are called, the message
    # will be added to a queue, otherwise they are logged immediately.
    # The message queue is flushed by calling #flush_queue, which is
    # called from Bolt::CLI after configuring the logger.
    #
    def self.warn(id, msg)
      log(type: :warn, msg: "#{msg} [ID: #{id}]", id: id)
    end

    def self.warn_once(id, msg)
      log(type: :warn_once, msg: "#{msg} [ID: #{id}]", id: id)
    end

    def self.deprecate(id, msg)
      log(type: :deprecate, msg: "#{msg} [ID: #{id}]", id: id)
    end

    def self.deprecate_once(id, msg)
      log(type: :deprecate_once, msg: "#{msg} [ID: #{id}]", id: id)
    end

    def self.debug(msg)
      log(type: :debug, msg: msg)
    end

    def self.info(msg)
      log(type: :info, msg: msg)
    end

    # Logs a message. If the logger has not been configured, this will queue
    # the message to be logged later. Once the logger is configured, the
    # queue will be flushed of all messages and new messages will be logged
    # immediately.
    #
    # Logging with this method is controlled by a mutex, as the Bolt::Logger
    # module is treated as a global singleton to allow multiple classes
    # access to its methods.
    #
    private_class_method def self.log(type:, msg:, id: nil)
      @mutex.synchronize do
        if configured?
          log_message(type: type, msg: msg, id: id)
        else
          @message_queue << { type: type, msg: msg, id: id }
        end
      end
    end

    # Logs all messages in the message queue and then flushes the queue.
    #
    def self.flush_queue
      @mutex.synchronize do
        @message_queue.each do |message|
          log_message(**message)
        end

        @message_queue.clear
      end
    end

    # Handles the actual logging of a message.
    #
    private_class_method def self.log_message(type:, msg:, id: nil)
      case type
      when :warn
        do_warn(msg, id)
      when :warn_once
        do_warn_once(msg, id)
      when :deprecate
        do_deprecate(msg, id)
      when :deprecate_once
        do_deprecate_once(msg, id)
      else
        logger(self).send(type, msg)
      end
    end

    # The following methods do the actual warning.
    #
    private_class_method def self.do_warn(msg, id)
      return if @disable_warnings.include?(id)
      logger(self).warn(msg)
    end

    private_class_method def self.do_warn_once(msg, id)
      return unless @warnings.add?(id)
      do_warn(msg, id)
    end

    private_class_method def self.do_deprecate(msg, id)
      @analytics&.event('Warn', 'deprecation', label: id)
      do_warn(msg, id)
    end

    private_class_method def self.do_deprecate_once(msg, id)
      @analytics&.event('Warn', 'deprecation', label: id)
      do_warn_once(msg, id)
    end
  end
end
