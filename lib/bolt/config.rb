# frozen_string_literal: true

require 'yaml'
require 'logging'
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

  Config = Struct.new(
    :concurrency,
    :format,
    :trace,
    :inventoryfile,
    :log,
    :modulepath,
    :puppetdb,
    :'hiera-config',
    :color,
    :transport,
    :transports
  ) do

    DEFAULTS = {
      concurrency: 100,
      transport: 'ssh',
      format: 'human',
      modulepath: [],
      puppetdb: {},
      color: true
    }.freeze

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

    BOLTDIR_NAME = 'Boltdir'

    def initialize(**kwargs)
      super()
      @logger = Logging.logger[self]
      @pwd = kwargs.delete(:pwd)

      DEFAULTS.merge(kwargs).each { |k, v| self[k] = v }

      # add an entry for the default console logger
      self[:log] ||= {}
      self[:log]['console'] ||= {}

      self[:transports] ||= {}
      TRANSPORTS.each_key do |transport|
        self[:transports][transport] ||= {}

        TRANSPORT_DEFAULTS.each do |k, v|
          unless self[:transports][transport][k]
            self[:transports][transport][k] = v
          end
        end

        TRANSPORT_SPECIFIC_DEFAULTS[transport].each do |k, v|
          unless self[:transports][transport].key? k
            self[:transports][transport][k] = v
          end
        end
      end
    end

    def deep_clone
      Bolt::Util.deep_clone(self)
    end

    def normalize_log(target)
      return target if target == 'console'
      target = target[5..-1] if target.start_with?('file:')
      'file:' + File.expand_path(target)
    end

    def update_from_file(data)
      if data['log'].is_a?(Hash)
        data['log'].each_pair do |k, v|
          log = (self[:log][normalize_log(k)] ||= {})

          next unless v.is_a?(Hash)

          if v.key?('level')
            log[:level] = v['level'].to_s
          end

          if v.key?('append')
            log[:append] = v['append']
          end
        end
      end

      if data['modulepath']
        self[:modulepath] = data['modulepath'].split(File::PATH_SEPARATOR)
      end

      %w[inventoryfile concurrency format puppetdb hiera-config color transport].each do |key|
        if data.key?(key)
          self[key.to_sym] = data[key]
        end
      end

      TRANSPORTS.each do |key, impl|
        if data[key.to_s]
          selected = data[key.to_s].select { |k| impl.options.include?(k) }
          self[:transports][key].merge!(selected)
        end
      end
    end
    private :update_from_file

    def find_boltdir(dir)
      path = dir
      boltdir = nil
      while boltdir.nil? && path && path != File.dirname(path)
        maybe_boltdir = File.join(path, BOLTDIR_NAME)
        boltdir = maybe_boltdir if File.directory?(maybe_boltdir)
        path = File.dirname(path)
      end
      boltdir
    end

    def pwd
      @pwd ||= Dir.pwd
    end

    def boltdir
      @boltdir ||= find_boltdir(pwd) || default_boltdir
    end

    def default_boltdir
      File.expand_path(File.join('~', '.puppetlabs', 'bolt'))
    end

    def default_modulepath
      [File.join(boltdir, "modules")]
    end

    # TODO: This is deprecated in 0.21.0 and can be removed in release 0.22.0.
    def legacy_conf
      return @legacy_conf if defined?(@legacy_conf)
      root_path = File.expand_path(File.join('~', '.puppetlabs'))
      legacy_paths = [File.join(root_path, 'bolt.yaml'), File.join(root_path, 'bolt.yml')]
      @legacy_conf = legacy_paths.find { |path| File.exist?(path) }
      @legacy_conf ||= legacy_paths[0]
      if @legacy_conf
        correct_path = File.join(default_boltdir, 'bolt.yaml')
        msg = "Found configfile at deprecated location #{@legacy_conf}. Global config should be in #{correct_path}"
        @logger.warn(msg)
      end
      @legacy_conf
    end

    def default_config
      path = File.join(boltdir, 'bolt.yaml')
      File.exist?(path) ? path : legacy_conf
    end

    def default_inventory
      File.join(boltdir, 'inventory.yaml')
    end

    def default_hiera
      File.join(boltdir, 'hiera.yaml')
    end

    def update_from_cli(options)
      %i[concurrency transport format trace modulepath inventoryfile color].each do |key|
        self[key] = options[key] if options.key?(key)
      end

      if options[:debug]
        self[:log]['console'][:level] = :debug
      elsif options[:verbose]
        self[:log]['console'][:level] = :info
      end

      TRANSPORTS.each_key do |transport|
        transport = self[:transports][transport]
        TRANSPORT_OPTIONS.each do |key|
          if options[key]
            transport[key.to_s] = Bolt::Util.walk_keys(options[key], &:to_s)
          end
        end
      end

      if options.key?(:ssl) # this defaults to true so we need to check the presence of the key
        self[:transports][:winrm]['ssl'] = options[:ssl]
      end

      if options.key?(:'ssl-verify') # this defaults to true so we need to check the presence of the key
        self[:transports][:winrm]['ssl-verify'] = options[:'ssl-verify']
      end

      if options.key?(:'host-key-check') # this defaults to true so we need to check the presence of the key
        self[:transports][:ssh]['host-key-check'] = options[:'host-key-check']
      end
    end

    # Defaults that do not vary based on boltdir should not be included here.
    #
    # Defaults which are treated differently from specified values like
    # 'inventoryfile' cannot be included here or they will not be handled correctly.
    def update_from_defaults
      self[:modulepath] = default_modulepath
      self[:'hiera-config'] = default_hiera
    end

    # The order in which config is processed is important
    def update(options)
      update_from_defaults
      load_file(options[:configfile])
      update_from_cli(options)
    end

    def load_file(path)
      data = Bolt::Util.read_config_file(path, [default_config], 'config')
      update_from_file(data) if data
      validate_hiera_conf(data ? data['hiera-config'] : nil)
    end

    def update_from_inventory(data)
      update_from_file(data)

      if data['transport']
        self[:transport] = data['transport']
      end
    end

    def transport_conf
      { transport: self[:transport],
        transports: self[:transports] }
    end

    def validate_hiera_conf(path)
      Bolt::Util.read_config_file(path, [default_hiera], 'hiera-config')
    end

    def validate
      self[:log].each_pair do |name, params|
        if params.key?(:level) && !Bolt::Logger.valid_level?(params[:level])
          raise Bolt::ValidationError,
                "level of log #{name} must be one of: #{Bolt::Logger.levels.join(', ')}; received #{params[:level]}"
        end
        if params.key?(:append) && params[:append] != true && params[:append] != false
          raise Bolt::ValidationError, "append flag of log #{name} must be a Boolean, received #{params[:append]}"
        end
      end

      unless %w[human json].include? self[:format]
        raise Bolt::ValidationError, "Unsupported format: '#{self[:format]}'"
      end

      unless self[:transport].nil? || Bolt::TRANSPORTS.include?(self[:transport].to_sym)
        raise UnknownTransportError, self[:transport]
      end

      TRANSPORTS.each do |transport, impl|
        impl.validate(self[:transports][transport])
      end
    end
  end
end
