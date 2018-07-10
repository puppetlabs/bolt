# frozen_string_literal: true

require 'json'
require 'bolt/util'

module Bolt
  module PuppetDB
    class Config
      if !ENV['HOME'].nil?
        DEFAULT_TOKEN = File.expand_path('~/.puppetlabs/token')
        DEFAULT_CONFIG = { user: File.expand_path('~/.puppetlabs/client-tools/puppetdb.conf'),
                           global: '/etc/puppetlabs/client-tools/puppetdb.conf',
                           win_global: 'C:/ProgramData/PuppetLabs/client-tools/puppetdb.conf' }.freeze
      else
        DEFAULT_TOKEN = "/etc/puppetlabs/client-tools/pe-bolt-server/token"
        DEFAULT_CONFIG = { user: "/etc/puppetlabs/puppet/puppetdb.conf",
                           global: '/etc/puppetlabs/puppet/puppetdb.conf',
                           win_global: 'C:/ProgramData/PuppetLabs/client-tools/puppetdb.conf' }.freeze

      end

      def initialize(config_file, options)
        @settings = load_config(config_file)
        @settings.merge!(options)
        expand_paths
        validate
      end

      def load_config(filename)
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
