# frozen_string_literal: true

require 'hocon'

class TransportConfig
  attr_accessor :host, :port, :ssl_cert, :ssl_key, :ssl_ca_cert, :ssl_cipher_suites,
                :loglevel, :logfile, :whitelist, :concurrency

  def initialize(global = nil, local = nil)
    @host = '127.0.0.1'
    @port = 62658
    @ssl_cert = nil
    @ssl_key = nil
    @ssl_ca_cert = nil
    @ssl_cipher_suites = ['ECDHE-ECDSA-AES256-GCM-SHA384',
                          'ECDHE-RSA-AES256-GCM-SHA384',
                          'ECDHE-ECDSA-CHACHA20-POLY1305',
                          'ECDHE-RSA-CHACHA20-POLY1305',
                          'ECDHE-ECDSA-AES128-GCM-SHA256',
                          'ECDHE-RSA-AES128-GCM-SHA256',
                          'ECDHE-ECDSA-AES256-SHA384',
                          'ECDHE-RSA-AES256-SHA384',
                          'ECDHE-ECDSA-AES128-SHA256',
                          'ECDHE-RSA-AES128-SHA256']

    @loglevel = 'notice'
    @logfile = nil
    @whitelist = nil
    @concurrency = 100

    global_path = global || '/etc/puppetlabs/bolt-server/conf.d/bolt-server.conf'
    local_path = local || File.join(ENV['HOME'].to_s, ".puppetlabs", "bolt-server.conf")

    load_config(global_path)
    load_config(local_path)
    validate
  end

  def load_config(path)
    begin
      parsed_hocon = Hocon.load(path)['bolt-server']
    rescue Hocon::ConfigError => e
      raise "Hocon data in '#{path}' failed to load.\n Error: '#{e.message}'"
    rescue Errno::EACCES
      raise "Your user doesn't have permission to read #{path}"
    end

    unless parsed_hocon.nil?
      %w[host port ssl-cert ssl-key ssl-ca-cert ssl-cipher-suites loglevel logfile whitelist concurrency].each do |key|
        varname = '@' + key.tr('-', '_')
        instance_variable_set(varname, parsed_hocon[key]) if parsed_hocon.key?(key)
      end
    end
  end

  def validate
    required_keys = %w[ssl_cert ssl_key ssl_ca_cert]
    ssl_keys = %w[ssl_cert ssl_key ssl_ca_cert]
    required_keys.each do |k|
      next unless send(k).nil?
      raise Bolt::ValidationError, <<-MSG
You must configure #{k} in either /etc/puppetlabs/bolt-server/conf.d/bolt-server.conf or ~/.puppetlabs/bolt-server.conf
      MSG
    end

    unless @port.is_a?(Integer) && @port > 0
      raise Bolt::ValidationError, "Configured 'port' must be a valid integer greater than 0"
    end
    ssl_keys.each do |sk|
      unless File.file?(send(sk)) && File.readable?(send(sk))
        raise Bolt::ValidationError, "Configured #{sk} must be a valid filepath"
      end
    end

    unless @ssl_cipher_suites.is_a?(Array)
      raise Bolt::ValidationError, "Configured 'ssl-cipher-suites' must be an array of cipher suite names"
    end

    unless @whitelist.nil? || @whitelist.is_a?(Array)
      raise Bolt::ValidationError, "Configured 'whitelist' must be an array of names"
    end

    unless @concurrency.is_a?(Integer) && @concurrency.positive?
      raise Bolt::ValidationError, "Configured 'concurrency' must be a positive integer"
    end
  end
end
