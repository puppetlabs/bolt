# frozen_string_literal: true

require 'hocon'

class TransportConfig
  attr_accessor :host, :port, :ssl_cert, :ssl_key, :ssl_ca_cert

  def initialize(global = nil, local = nil)
    @host = '127.0.0.1'
    @port = 62658
    @ssl_cert = nil
    @ssl_key = nil
    @ssl_ca_cert = nil

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
      @host = parsed_hocon['host'] if parsed_hocon.key?('host')
      @port = parsed_hocon['port'] if parsed_hocon.key?('port')
      @ssl_cert = parsed_hocon['ssl-cert'] if parsed_hocon.key?('ssl-cert')
      @ssl_key = parsed_hocon['ssl-key'] if parsed_hocon.key?('ssl-key')
      @ssl_ca_cert = parsed_hocon['ssl-ca-cert'] if parsed_hocon.key?('ssl-ca-cert')
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
  end
end
