# frozen_string_literal: true

require 'hocon'

class TransportConfig
  attr_accessor :port

  def initialize(global = nil, local = nil)
    @port = 8144

    global_path = global || '/etc/puppetlabs/bolt-server/conf.d/bolt-server.conf'
    local_path = local || File.join(ENV['HOME'].to_s, ".puppetlabs", "bolt-server.conf")

    load_config(global_path)
    load_config(local_path)
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
      @port = parsed_hocon['port'] if parsed_hocon.key?('port')
    end
  end

  def validate
    unless @port.is_a?(Integer) && @port > 0
      raise Bolt::ValidationError, 'Port must be a valid integer greater than 0'
    end
  end
end
