# frozen_string_literal: true

require 'bolt/version'
require 'httpclient'
require 'json'
require 'locale'
require 'logging'
require 'securerandom'

module Bolt
  module Analytics
    PROTOCOL_VERSION = 1
    APPLICATION_NAME = 'bolt'
    TRACKING_ID = 'UA-120367942-1'
    TRACKING_URL = 'https://google-analytics.com/collect'

    def self.build_client
      logger = Logging.logger[self]

      config_file = File.expand_path('~/.puppetlabs/bolt/analytics.yaml')
      config = load_config(config_file)

      if config['disabled'] || ENV['BOLT_DISABLE_ANALYTICS']
        logger.debug "Analytics opt-out is set, analytics will be disabled"
        NoopClient.new
      else
        unless config.key?('user-id')
          config['user-id'] = SecureRandom.uuid
          write_config(config_file, config)
        end

        Client.new(config['user-id'])
      end
    rescue StandardError => e
      logger.debug "Failed to initialize analytics client, analytics will be disabled: #{e}"
      NoopClient.new
    end

    def self.load_config(filename)
      if File.exist?(filename)
        YAML.load_file(filename)
      else
        {}
      end
    end

    def self.write_config(filename, config)
      FileUtils.mkdir_p(File.dirname(filename))
      File.write(filename, config.to_yaml)
    end

    class Client
      attr_reader :user_id

      def initialize(user_id)
        @logger = Logging.logger[self]
        @http = HTTPClient.new
        @user_id = user_id
        @executor = Concurrent.global_io_executor
        @os = compute_os
      end

      def screen_view(screen)
        screen_view_params = {
          # Type
          t: 'screenview',
          # Screen Name
          cd: screen
        }

        submit(base_params.merge(screen_view_params))
      end

      def event(category, action)
        event_params = {
          # Type
          t: 'event',
          # Event Category
          ec: category,
          # Event Action
          ea: action
        }

        submit(base_params.merge(event_params))
      end

      def submit(params)
        # Handle analytics submission in the background to avoid blocking the
        # app or polluting the log with errors
        Concurrent::Future.execute(executor: @executor) do
          @logger.debug "Submitting analytics: #{JSON.pretty_generate(params)}"
          @http.post(TRACKING_URL, params)
          @logger.debug "Completed analytics submission"
        end
      end

      # These parameters have terrible names. See this page for complete documentation:
      # https://developers.google.com/analytics/devguides/collection/protocol/v1/parameters
      def base_params
        {
          v: PROTOCOL_VERSION,
          # Client ID
          cid: @user_id,
          # Tracking ID
          tid: TRACKING_ID,
          # Application Name
          an: APPLICATION_NAME,
          # Application Version
          av: Bolt::VERSION,
          # Anonymize IPs
          aip: true,
          # User locale
          ul: Locale.current.to_rfc,
          # Custom Dimension 1 (Operating System)
          cd1: @os.value
        }
      end

      def compute_os
        Concurrent::Future.execute(executor: @executor) do
          require_relative '../../vendored/require_vendored'
          require 'facter'
          os = Facter.value('os')
          "#{os['name']} #{os.dig('release', 'major')}"
        end
      end

      # If the user is running a very fast command, there may not be time for
      # analytics submission to complete before the command is finished. In
      # that case, we give a little buffer for any stragglers to finish up.
      # 250ms strikes a balance between accomodating slower networks while not
      # introducing a noticeable "hang".
      def finish
        @executor.shutdown
        @executor.wait_for_termination(0.25)
      end
    end

    class NoopClient
      def initialize
        @logger = Logging.logger[self]
      end

      def screen_view(screen)
        @logger.debug "Skipping submission of '#{screen}' screenview because analytics is disabled"
      end

      def event(category, action)
        @logger.debug "Skipping submission of '#{category} #{action}' event because analytics is disabled"
      end

      def finish; end
    end
  end
end
