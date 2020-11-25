# frozen_string_literal: true

require 'hocon'
require 'bolt_server/base_config'
require 'bolt/error'

module BoltServer
  class Config < BoltServer::BaseConfig
    def config_keys
      super + %w[concurrency cache-dir file-server-conn-timeout
                 file-server-uri projects-dir environments-codedir
                 environmentpath basemodulepath]
    end

    def env_keys
      super + %w[concurrency file-server-conn-timeout file-server-uri]
    end

    def int_keys
      %w[concurrency file-server-conn-timeout]
    end

    def defaults
      super.merge(
        'port' => 62658,
        'concurrency' => 100,
        'cache-dir' => "/opt/puppetlabs/server/data/bolt-server/cache",
        'file-server-conn-timeout' => 120
      )
    end

    def required_keys
      super + %w[file-server-uri]
    end

    def service_name
      'bolt-server'
    end

    def load_env_config
      env_keys.each do |key|
        transformed_key = "BOLT_#{key.tr('-', '_').upcase}"
        next unless ENV.key?(transformed_key)
        @data[key] = if int_keys.include?(key)
                       ENV[transformed_key].to_i
                     else
                       ENV[transformed_key]
                     end
      end
    end

    def validate
      super

      unless natural?(@data['concurrency'])
        raise Bolt::ValidationError, "Configured 'concurrency' must be a positive integer"
      end

      unless natural?(@data['file-server-conn-timeout'])
        raise Bolt::ValidationError, "Configured 'file-server-conn-timeout' must be a positive integer"
      end
    end
  end
end
