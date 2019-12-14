# frozen_string_literal: true

require 'hocon'
require 'bolt/error'

module BoltServer
  class BaseConfig
    def config_keys
      %w[host port status-port
         ssl-cert ssl-key ssl-ca-cert ssl-cipher-suites
         loglevel logfile whitelist]
    end

    def env_keys
      %w[ssl-cert ssl-key ssl-ca-cert loglevel]
    end

    def defaults
      { 'host' => '127.0.0.1',
        'loglevel' => 'notice',
        'ssl-cipher-suites' => %w[ECDHE-ECDSA-AES256-GCM-SHA384
                                  ECDHE-RSA-AES256-GCM-SHA384
                                  ECDHE-ECDSA-CHACHA20-POLY1305
                                  ECDHE-RSA-CHACHA20-POLY1305
                                  ECDHE-ECDSA-AES128-GCM-SHA256
                                  ECDHE-RSA-AES128-GCM-SHA256
                                  ECDHE-ECDSA-AES256-SHA384
                                  ECDHE-RSA-AES256-SHA384
                                  ECDHE-ECDSA-AES128-SHA256
                                  ECDHE-RSA-AES128-SHA256] }
    end

    def ssl_keys
      %w[ssl-cert ssl-key ssl-ca-cert]
    end

    def required_keys
      ssl_keys
    end

    def service_name
      raise "Method service_name must be defined in the service class"
    end

    def initialize(config = nil)
      @data = defaults
      @data = @data.merge(config.select { |key, _| config_keys.include?(key) }) if config
      @config_path = nil
    end

    def load_file_config(path)
      @config_path = path
      begin
        # This lets us get the actual config values without needing to
        # know the service name
        parsed_hocon = Hocon.load(path)[service_name]
      rescue Hocon::ConfigError => e
        raise "Hocon data in '#{path}' failed to load.\n Error: '#{e.message}'"
      rescue Errno::EACCES
        raise "Your user doesn't have permission to read #{path}"
      end

      raise "Could not find service config at #{path}" if parsed_hocon.nil?

      parsed_hocon = parsed_hocon.select { |key, _| config_keys.include?(key) }

      @data = @data.merge(parsed_hocon)
    end

    def load_env_config
      raise "load_env_config should be defined in the service class"
    end

    def natural?(num)
      num.is_a?(Integer) && num.positive?
    end

    def validate
      required_keys.each do |k|
        # Handled nested config
        if k.is_a?(Array)
          next unless @data.dig(*k).nil?
        else
          next unless @data[k].nil?
        end
        raise Bolt::ValidationError, "You must configure #{k} in #{@config_path}"
      end

      unless natural?(@data['port'])
        raise Bolt::ValidationError, "Configured 'port' must be a valid integer greater than 0"
      end
      ssl_keys.each do |sk|
        unless File.file?(@data[sk]) && File.readable?(@data[sk])
          raise Bolt::ValidationError, "Configured #{sk} must be a valid filepath"
        end
      end

      unless @data['ssl-cipher-suites'].is_a?(Array)
        raise Bolt::ValidationError, "Configured 'ssl-cipher-suites' must be an array of cipher suite names"
      end

      unless @data['whitelist'].nil? || @data['whitelist'].is_a?(Array)
        raise Bolt::ValidationError, "Configured 'whitelist' must be an array of names"
      end
    end

    def [](key)
      @data[key]
    end
  end
end
