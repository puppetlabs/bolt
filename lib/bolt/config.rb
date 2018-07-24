# frozen_string_literal: true

require 'yaml'
require 'logging'
require 'concurrent'
require 'pathname'
require 'bolt/boltdir'
require 'bolt/cli'
require 'bolt/transport/ssh'
require 'bolt/transport/winrm'
require 'bolt/transport/orch'
require 'bolt/transport/local'

module Bolt
  TRANSPORTS = {
    ssh: Bolt::Transport::SSH,
    winrm: Bolt::Transport::WinRM,
    pcp: Bolt::Transport::Orch,
    local: Bolt::Transport::Local
  }.freeze

  class UnknownTransportError < Bolt::Error
    def initialize(transport, uri = nil)
      msg = uri.nil? ? "Unknown transport #{transport}" : "Unknown transport #{transport} found for #{uri}"
      super(msg, 'bolt/unknown-transport')
    end
  end

  class Config
    attr_accessor :concurrency, :format, :trace, :log, :puppetdb, :color,
                  :transport, :transports, :inventoryfile, :compile_concurrency
    attr_writer :modulepath

    TRANSPORT_OPTIONS = %i[password run-as sudo-password extensions
                           private-key tty tmpdir user connect-timeout
                           cacert token-file service-url].freeze

    TRANSPORT_DEFAULTS = {
      'connect-timeout' => 10,
      'tty' => false
    }.freeze

    TRANSPORT_SPECIFIC_DEFAULTS = {
      ssh: {
        'host-key-check' => true
      },
      winrm: {
        'ssl' => true,
        'ssl-verify' => true
      },
      pcp: {
        'task-environment' => 'production',
        'local-validation' => false
      },
      local: {}
    }.freeze

    def self.default
      new(Bolt::Boltdir.new('.'), {})
    end

    def self.from_boltdir(boltdir, overrides = {})
      # *Optionally* load the boltdir config file, and fall back to the legacy
      # config if that isn't found. Because logging is built in to the
      # legacy_conf method, we don't want to look that up unless we need it.
      configs = if boltdir.config_file.exist?
                  [boltdir.config_file]
                else
                  [legacy_conf]
                end

      data = Bolt::Util.read_config_file(nil, configs, 'config') || {}

      new(boltdir, data, overrides)
    end

    def self.from_file(configfile, overrides = {})
      boltdir = Bolt::Boltdir.new(Pathname.new(configfile).expand_path.dirname)
      data = Bolt::Util.read_config_file(configfile, [], 'config') || {}

      new(boltdir, data, overrides)
    end

    def initialize(boltdir, config_data, overrides = {})
      @logger = Logging.logger[self]

      @boltdir = boltdir
      @concurrency = 100
      @compile_concurrency = Concurrent.processor_count
      @transport = 'ssh'
      @format = 'human'
      @puppetdb = {}
      @color = true

      # add an entry for the default console logger
      @log = { 'console' => {} }

      @transports = {}
      TRANSPORTS.each_key do |transport|
        @transports[transport] = TRANSPORT_DEFAULTS.merge(TRANSPORT_SPECIFIC_DEFAULTS[transport])
      end

      update_from_file(config_data)
      apply_overrides(overrides)

      validate
    end

    def deep_clone
      Bolt::Util.deep_clone(self)
    end

    def normalize_log(target)
      return target if target == 'console'
      target = target[5..-1] if target.start_with?('file:')
      'file:' + File.expand_path(target)
    end

    def update_logs(logs)
      logs.each_pair do |k, v|
        log_name = normalize_log(k)
        @log[log_name] ||= {}
        log = @log[log_name]

        next unless v.is_a?(Hash)

        if v.key?('level')
          log[:level] = v['level'].to_s
        end

        if v.key?('append')
          log[:append] = v['append']
        end
      end
    end

    def update_from_file(data)
      if data['log'].is_a?(Hash)
        update_logs(data['log'])
      end

      @modulepath = data['modulepath'].split(File::PATH_SEPARATOR) if data.key?('modulepath')

      @inventoryfile = data['inventoryfile'] if data.key?('inventoryfile')

      @hiera_config = data['hiera-config'] if data.key?('hiera-config')
      @compile_concurrency = data['compile-concurrency'] if data.key?('compile-concurrency')

      %w[concurrency format puppetdb color transport].each do |key|
        send("#{key}=", data[key]) if data.key?(key)
      end

      TRANSPORTS.each do |key, impl|
        if data[key.to_s]
          selected = data[key.to_s].select { |k| impl.options.include?(k) }
          @transports[key].merge!(selected)
        end
      end
    end
    private :update_from_file

    # TODO: This is deprecated in 0.21.0 and can be removed in release 0.22.0.
    def self.legacy_conf
      root_path = File.expand_path(File.join('~', '.puppetlabs'))
      legacy_paths = [File.join(root_path, 'bolt.yaml'), File.join(root_path, 'bolt.yml')]
      legacy_conf = legacy_paths.find { |path| File.exist?(path) }
      found_legacy_conf = !!legacy_conf
      legacy_conf ||= legacy_paths[0]
      if found_legacy_conf
        correct_path = Bolt::Boltdir.default_boltdir.config_file
        msg = "Found configfile at deprecated location #{legacy_conf}. Global config should be in #{correct_path}"
        Logging.logger[self].warn(msg)
      end
      legacy_conf
    end

    def apply_overrides(options)
      %i[concurrency transport format trace modulepath inventoryfile color].each do |key|
        send("#{key}=", options[key]) if options.key?(key)
      end

      if options[:debug]
        @log['console'][:level] = :debug
      elsif options[:verbose]
        @log['console'][:level] = :info
      end

      @compile_concurrency = options[:'compile-concurrency'] if options[:'compile-concurrency']

      TRANSPORTS.each_key do |transport|
        transport = @transports[transport]
        TRANSPORT_OPTIONS.each do |key|
          if options[key]
            transport[key.to_s] = Bolt::Util.walk_keys(options[key], &:to_s)
          end
        end
      end

      if options.key?(:ssl) # this defaults to true so we need to check the presence of the key
        @transports[:winrm]['ssl'] = options[:ssl]
      end

      if options.key?(:'ssl-verify') # this defaults to true so we need to check the presence of the key
        @transports[:winrm]['ssl-verify'] = options[:'ssl-verify']
      end

      if options.key?(:'host-key-check') # this defaults to true so we need to check the presence of the key
        @transports[:ssh]['host-key-check'] = options[:'host-key-check']
      end
    end

    def update_from_inventory(data)
      update_from_file(data)

      if data['transport']
        @transport = data['transport']
      end
    end

    def transport_conf
      { transport: @transport,
        transports: @transports }
    end

    def default_inventoryfile
      [@boltdir.inventory_file]
    end

    def hiera_config
      @hiera_config || @boltdir.hiera_config
    end

    def puppetfile
      @boltdir.puppetfile
    end

    def modulepath
      @modulepath || @boltdir.modulepath
    end

    def validate
      @log.each_pair do |name, params|
        if params.key?(:level) && !Bolt::Logger.valid_level?(params[:level])
          raise Bolt::ValidationError,
                "level of log #{name} must be one of: #{Bolt::Logger.levels.join(', ')}; received #{params[:level]}"
        end
        if params.key?(:append) && params[:append] != true && params[:append] != false
          raise Bolt::ValidationError, "append flag of log #{name} must be a Boolean, received #{params[:append]}"
        end
      end

      unless @concurrency.is_a?(Integer) && @concurrency > 0
        raise Bolt::ValidationError, 'Concurrency must be a positive integer'
      end

      unless @compile_concurrency.is_a?(Integer) && @compile_concurrency > 0
        raise Bolt::ValidationError, 'Compile concurrency must be a positive integer'
      end

      compile_limit = 2 * Concurrent.processor_count
      unless @compile_concurrency < compile_limit
        raise Bolt::ValidationError, "Compilation is CPU-intensive, set concurrency less than #{compile_limit}"
      end

      unless %w[human json].include? @format
        raise Bolt::ValidationError, "Unsupported format: '#{@format}'"
      end

      if @hiera_config && !(File.file?(@hiera_config) && File.readable?(@hiera_config))
        raise Bolt::FileError, "Could not read hiera-config file #{@hiera_config}", @hiera_config
      end

      unless @transport.nil? || Bolt::TRANSPORTS.include?(@transport.to_sym)
        raise UnknownTransportError, @transport
      end

      TRANSPORTS.each do |transport, impl|
        impl.validate(@transports[transport])
      end
    end
  end
end
