# frozen_string_literal: true

require 'json'
require 'bolt/util'

module Bolt
  module PuppetDB
    class Config
      DEFAULT_TOKEN = File.expand_path('~/.puppetlabs/token')
      DEFAULT_CONFIG = { user: File.expand_path('~/.puppetlabs/client-tools/puppetdb.conf'),
                         global: '/etc/puppetlabs/client-tools/puppetdb.conf',
                         win_global: 'C:/ProgramData/PuppetLabs/client-tools/puppetdb.conf' }.freeze

      def self.load_config(filename, options)
        global_path = Bolt::Util.windows? ? DEFAULT_CONFIG[:win_global] : DEFAULT_CONFIG[:global]
        if filename
          if File.exist?(filename)
            config = JSON.parse(File.read(filename))
          else
            raise Bolt::PuppetDBError, "config file #{filename} does not exist"
          end
        elsif File.exist?(DEFAULT_CONFIG[:user])
          config = JSON.parse(File.read(DEFAULT_CONFIG[:user]))
        elsif File.exist?(global_path)
          config = JSON.parse(File.read(global_path))
        else
          config = {}
        end
        config = config.fetch('puppetdb', {})
        new(config.merge(options))
      end

      def initialize(settings)
        @settings = settings
        expand_paths
      end

      def token
        return @token if @token
        if @settings['token']
          @token = File.read(@settings['token'])
        elsif File.exist?(DEFAULT_TOKEN)
          @token = File.read(DEFAULT_TOKEN)
        end
      end

      def expand_paths
        %w[cacert cert key token].each do |file|
          @settings[file] = File.expand_path(@settings[file]) if @settings[file]
        end
      end

      def validate_file_exists(file)
        if @settings[file] && !File.exist?(@settings[file])
          raise Bolt::PuppetDBError, "#{file} file #{@settings[file]} does not exist"
        end
        true
      end

      def uri
        return @uri if @uri
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

        @uri = URI.parse(uri)
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

      def to_hash
        @settings.dup
      end
    end
  end
end
