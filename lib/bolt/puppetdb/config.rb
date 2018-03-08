require 'json'

module Bolt
  module PuppetDB
    class Config
      DEFAULT_TOKEN = File.expand_path('~/.puppetlabs/token')
      DEFAULT_CONFIG = File.expand_path('~/.puppetlabs/client-tools/puppetdb.conf')

      def initialize(config_file, options)
        @settings = load_config(config_file)
        @settings.merge!(options)

        expand_paths
        validate
      end

      def load_config(filename)
        if filename
          if File.exist?(filename)
            config = JSON.parse(File.read(filename))
          else
            raise Bolt::PuppetDBError, "config file #{filename} does not exist"
          end
        elsif File.exist?(DEFAULT_CONFIG)
          config = JSON.parse(File.read(DEFAULT_CONFIG))
        else
          config = {}
        end
        config.fetch('puppetdb', {})
      end

      def token
        return @token if @token
        if @settings['token']
          File.read(@settings['token'])
        elsif File.exist?(DEFAULT_TOKEN)
          File.read(DEFAULT_TOKEN)
        end
      end

      def [](key)
        @settings[key]
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
      end

      def validate
        unless @settings['server_urls']
          raise Bolt::PuppetDBError, "server_urls must be specified"
        end
        unless @settings['cacert']
          raise Bolt::PuppetDBError, "cacert must be specified"
        end

        if (@settings['cert'] && !@settings['key']) ||
           (!@settings['cert'] && @settings['key'])
          raise Bolt::PuppetDBError, "cert and key must be specified together"
        end

        validate_file_exists('cacert')
        validate_file_exists('cert')
        validate_file_exists('key')
      end
    end
  end
end
