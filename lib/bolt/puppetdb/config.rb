# frozen_string_literal: true

require 'json'
require_relative '../../bolt/util'

module Bolt
  module PuppetDB
    class Config
      if ENV['HOME'].nil?
        DEFAULT_TOKEN = Bolt::Util.windows? ? 'nul' : '/dev/null'
        DEFAULT_CONFIG = { user: '/etc/puppetlabs/puppet/puppetdb.conf',
                           global: '/etc/puppetlabs/puppet/puppetdb.conf' }.freeze
      else
        DEFAULT_TOKEN = File.expand_path('~/.puppetlabs/token')
        DEFAULT_CONFIG = { user: File.expand_path('~/.puppetlabs/client-tools/puppetdb.conf'),
                           global: '/etc/puppetlabs/client-tools/puppetdb.conf' }.freeze

      end

      def initialize(config:, project: nil, load_defaults: false)
        @settings = if load_defaults
                      self.class.default_config.merge(config)
                    else
                      config
                    end

        expand_paths(project)
      end

      # Returns the path to the puppetdb.conf file on Windows.
      #
      # @return [String]
      #
      def self.default_windows_config
        File.expand_path(File.join(ENV['ALLUSERSPROFILE'], 'PuppetLabs/client-tools/puppetdb.conf'))
      end

      # Loads default configuration from the puppetdb.conf file on system. If
      # the file is not present, defaults to an empty hash.
      #
      # @return [Hash]
      #
      def self.default_config
        config = {}
        global_path = Bolt::Util.windows? ? default_windows_config : DEFAULT_CONFIG[:global]

        if File.exist?(DEFAULT_CONFIG[:user])
          filepath = DEFAULT_CONFIG[:user]
        elsif File.exist?(global_path)
          filepath = global_path
        end

        begin
          config = JSON.parse(File.read(filepath)) if filepath
        rescue StandardError => e
          Bolt::Logger.logger(self).error("Could not load puppetdb.conf from #{filepath}: #{e.message}")
        end

        config.fetch('puppetdb', {})
      end

      def token
        return @token if @token_computed
        # Allow nil in config to skip loading a token
        if @settings.include?('token')
          if @settings['token']
            @token = File.read(@settings['token'])
          end
        elsif File.exist?(DEFAULT_TOKEN)
          @token = File.read(DEFAULT_TOKEN)
        end
        # Only use cert based auth in the case token and cert are both configured
        if @token && cert
          Bolt::Logger.logger(self).debug("Both cert and token based auth configured, using cert only")
          @token = nil
        end
        @token_computed = true
        @token = @token.strip if @token
      end

      def expand_paths(project_path)
        %w[cacert cert key token].each do |file|
          next unless @settings[file]
          @settings[file] = File.expand_path(@settings[file], project_path)
        end
      end

      def validate_file_exists(file)
        if @settings[file] && !File.exist?(@settings[file])
          raise Bolt::PuppetDBError, "#{file} file #{@settings[file]} does not exist"
        end
        true
      end

      def server_urls
        case @settings['server_urls']
        when String
          [@settings['server_urls']]
        when Array
          @settings['server_urls']
        when nil
          raise Bolt::PuppetDBError, "server_urls must be specified"
        else
          raise Bolt::PuppetDBError, "server_urls must be a string or array"
        end
      end

      def uri
        return @uri if @uri
        require 'addressable/uri'

        uri = case @settings['server_urls']
              when String
                @settings['server_urls']
              when Array
                @settings['server_urls'].first
              when nil
                raise Bolt::PuppetDBError, "server_urls must be specified"
              else
                raise Bolt::PuppetDBError, "server_urls must be a string or array"
              end

        @uri = Addressable::URI.parse(uri)
        @uri.port ||= 8081
        @uri
      end

      def cacert
        if @settings['cacert'] && validate_file_exists('cacert')
          @settings['cacert']
        else
          raise Bolt::PuppetDBError, "cacert must be specified"
        end
      end

      def cert
        validate_cert_and_key
        validate_file_exists('cert')
        @settings['cert']
      end

      def key
        validate_cert_and_key
        validate_file_exists('key')
        @settings['key']
      end

      def validate_cert_and_key
        if (@settings['cert'] && !@settings['key']) ||
           (!@settings['cert'] && @settings['key'])
          raise Bolt::PuppetDBError, "cert and key must be specified together"
        end
      end

      def connect_timeout
        validate_timeout('connect_timeout')
        @settings['connect_timeout']
      end

      def read_timeout
        validate_timeout('read_timeout')
        @settings['read_timeout']
      end

      def validate_timeout(timeout)
        unless @settings[timeout].nil? || (@settings[timeout].is_a?(Integer) && @settings[timeout] > 0)
          raise Bolt::PuppetDBError, "#{timeout} must be a positive integer, received #{@settings[timeout]}"
        end
      end

      def to_hash
        @settings.dup
      end
    end
  end
end
