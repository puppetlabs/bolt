# frozen_string_literal: true

require 'hocon'
require 'bolt/error'

module BoltServer
  class Config
    CONFIG_KEYS = ['host', 'port', 'ssl-cert', 'ssl-key', 'ssl-ca-cert',
                   'ssl-cipher-suites', 'loglevel', 'logfile', 'whitelist', 'concurrency',
                   'cache-dir', 'file-server-uri'].freeze

    DEFAULTS = {
      'host' => '127.0.0.1',
      'port' => 62658,
      'ssl-cipher-suites' => ['ECDHE-ECDSA-AES256-GCM-SHA384',
                              'ECDHE-RSA-AES256-GCM-SHA384',
                              'ECDHE-ECDSA-CHACHA20-POLY1305',
                              'ECDHE-RSA-CHACHA20-POLY1305',
                              'ECDHE-ECDSA-AES128-GCM-SHA256',
                              'ECDHE-RSA-AES128-GCM-SHA256',
                              'ECDHE-ECDSA-AES256-SHA384',
                              'ECDHE-RSA-AES256-SHA384',
                              'ECDHE-ECDSA-AES128-SHA256',
                              'ECDHE-RSA-AES128-SHA256'],
      'loglevel' => 'notice',
      'concurrency' => 100,
      'cache-dir' => "/opt/puppetlabs/server/data/bolt-server/cache"
    }.freeze

    CONFIG_KEYS.each do |key|
      define_method(key.tr('-', '_').to_sym) do
        @data[key]
      end
    end

    def initialize(config = nil)
      @data = DEFAULTS.clone
      @data = @data.merge(config.select { |key, _| CONFIG_KEYS.include?(key) }) if config
      @config_path = nil
    end

    def load_config(path)
      @config_path = path
      begin
        parsed_hocon = Hocon.load(path)['bolt-server']
      rescue Hocon::ConfigError => e
        raise "Hocon data in '#{path}' failed to load.\n Error: '#{e.message}'"
      rescue Errno::EACCES
        raise "Your user doesn't have permission to read #{path}"
      end

      raise "Could not find bolt-server config at #{path}" if parsed_hocon.nil?

      parsed_hocon = parsed_hocon.select { |key, _| CONFIG_KEYS.include?(key) }
      @data = @data.merge(parsed_hocon)

      validate
      self
    end

    def validate
      # TODO: require file_server_uri once pl-pe code is in place
      required_keys = ['ssl-cert', 'ssl-key', 'ssl-ca-cert']
      ssl_keys = required_keys

      required_keys.each do |k|
        next unless @data[k].nil?
        raise Bolt::ValidationError, "You must configure #{k} in #{@config_path}"
      end

      unless port.is_a?(Integer) && port > 0
        raise Bolt::ValidationError, "Configured 'port' must be a valid integer greater than 0"
      end
      ssl_keys.each do |sk|
        unless File.file?(@data[sk]) && File.readable?(@data[sk])
          raise Bolt::ValidationError, "Configured #{sk} must be a valid filepath"
        end
      end

      unless ssl_cipher_suites.is_a?(Array)
        raise Bolt::ValidationError, "Configured 'ssl-cipher-suites' must be an array of cipher suite names"
      end

      unless whitelist.nil? || whitelist.is_a?(Array)
        raise Bolt::ValidationError, "Configured 'whitelist' must be an array of names"
      end

      unless concurrency.is_a?(Integer) && concurrency.positive?
        raise Bolt::ValidationError, "Configured 'concurrency' must be a positive integer"
      end
    end

    def [](key)
      @data[key]
    end
  end
end
