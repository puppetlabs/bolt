require 'yaml'
require 'bolt/cli'
require 'logging'

module Bolt
  TRANSPORTS = %i[ssh winrm pcp local].freeze

  Config = Struct.new(
    :concurrency,
    :format,
    :inventoryfile,
    :log_level,
    :log,
    :modulepath,
    :puppetdb,
    :transport,
    :transports
  ) do

    DEFAULTS = {
      concurrency: 100,
      transport: 'ssh',
      format: 'human',
      modulepath: [],
      puppetdb: {}
    }.freeze

    TRANSPORT_OPTIONS = %i[password run_as sudo_password extensions
                           key tty tmpdir user connect_timeout
                           cacert token-file service-url].freeze

    TRANSPORT_DEFAULTS = {
      connect_timeout: 10,
      tty: false
    }.freeze

    TRANSPORT_SPECIFIC_DEFAULTS = {
      ssh: {
        host_key_check: true
      },
      winrm: {
        ssl: true
      },
      pcp: {
        :"task-environment" => 'production',
        :"local-validation" => true
      },
      local: {}
    }.freeze

    def initialize(**kwargs)
      super()
      @logger = Logging.logger[self]
      DEFAULTS.merge(kwargs).each { |k, v| self[k] = v }

      # add an entry for the default console logger
      self[:log] ||= {}
      self[:log]['console'] ||= {}

      self[:transports] ||= {}
      TRANSPORTS.each do |transport|
        unless self[:transports][transport]
          self[:transports][transport] = {}
        end
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

    def default_paths
      root_path = File.expand_path(File.join('~', '.puppetlabs'))
      [File.join(root_path, 'bolt.yaml'), File.join(root_path, 'bolt.yml')]
    end

    def normalize_log(target)
      return target if target == 'console'
      target = target[5..-1] if target.start_with?('file:')
      'file:' << File.expand_path(target)
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

      if data['inventoryfile']
        self[:inventoryfile] = data['inventoryfile']
      end

      if data['concurrency']
        self[:concurrency] = data['concurrency']
      end

      if data['format']
        self[:format] = data['format']
      end

      if data['puppetdb']
        self[:puppetdb] = data['puppetdb']
      end

      if data['ssh']
        if data['ssh']['private-key']
          self[:transports][:ssh][:key] = data['ssh']['private-key']
        end
        if data['ssh'].key?('host-key-check')
          self[:transports][:ssh][:host_key_check] = data['ssh']['host-key-check']
        end
        if data['ssh']['connect-timeout']
          self[:transports][:ssh][:connect_timeout] = data['ssh']['connect-timeout']
        end
        if data['ssh']['tmpdir']
          self[:transports][:ssh][:tmpdir] = data['ssh']['tmpdir']
        end
        if data['ssh']['run-as']
          self[:transports][:ssh][:run_as] = data['ssh']['run-as']
        end
      end

      if data['winrm']
        if data['winrm']['connect-timeout']
          self[:transports][:winrm][:connect_timeout] = data['winrm']['connect-timeout']
        end
        if data['winrm'].key?('ssl')
          self[:transports][:winrm][:ssl] = data['winrm']['ssl']
        end
        if data['winrm']['tmpdir']
          self[:transports][:winrm][:tmpdir] = data['winrm']['tmpdir']
        end
        if data['winrm']['cacert']
          self[:transports][:winrm][:cacert] = data['winrm']['cacert']
        end
        if data['winrm']['extensions']
          # Accept a single entry or a list, ensure each is prefixed with '.'
          self[:transports][:winrm][:extensions] =
            [data['winrm']['extensions']].flatten.map { |ext| ext[0] != '.' ? '.' + ext : ext }
        end
      end

      if data['pcp']
        if data['pcp']['service-url']
          self[:transports][:pcp][:"service-url"] = data['pcp']['service-url']
        end
        if data['pcp']['cacert']
          self[:transports][:pcp][:cacert] = data['pcp']['cacert']
        end
        if data['pcp']['token-file']
          self[:transports][:pcp][:"token-file"] = data['pcp']['token-file']
        end
        if data['pcp']['task-environment']
          self[:transports][:pcp][:"task-environment"] = data['pcp']['task-environment']
        end
        if data['pcp'].key?('local-validation') # this defaults to true so we need to check the presence of the key
          self[:transports][:pcp][:"local-validation"] = data['pcp']['local-validation']
        end
      end

      if data['local']
        if data['local']['tmpdir']
          self[:transports][:local][:tmpdir] = data['local']['tmpdir']
        end
      end
    end
    private :update_from_file

    def load_file(path)
      data = Bolt::Util.read_config_file(path, default_paths, 'config')
      update_from_file(data) if data
    end

    def update_from_cli(options)
      %i[concurrency transport format modulepath inventoryfile].each do |key|
        self[key] = options[key] if options[key]
      end

      if options[:debug]
        self[:log]['console'][:level] = :debug
      elsif options[:verbose]
        self[:log]['console'][:level] = :info
      end

      TRANSPORTS.each do |transport|
        transport = self[:transports][transport]
        TRANSPORT_OPTIONS.each do |key|
          transport[key] = options[key] if options[key]
        end
      end

      if options.key?(:ssl) # this defaults to true so we need to check the presence of the key
        self[:transports][:winrm][:ssl] = options[:ssl]
      end

      if options.key?(:host_key_check) # this defaults to true so we need to check the presence of the key
        self[:transports][:ssh][:host_key_check] = options[:host_key_check]
      end
    end

    def update_from_inventory(data)
      update_from_file(data)

      if data['transport']
        self[:transport] = data['transport']
      end

      # Add options that aren't allowed in a config file, but are allowed in inventory
      %w[user password port].each do |opt|
        (TRANSPORTS - [:pcp]).each do |transport|
          if data[transport.to_s] && data[transport.to_s][opt]
            self[:transports][transport][opt.to_sym] = data[transport.to_s][opt]
          end
        end
      end

      if data['ssh'] && data['ssh']['sudo-password']
        self[:transports][:ssh][:sudo_password] = data['ssh']['sudo-password']
      end
    end

    def transport_conf
      { transport: self[:transport],
        transports: self[:transports] }
    end

    def validate
      TRANSPORTS.each do |transport|
        self[:transports][transport]
      end

      self[:log].each_pair do |name, params|
        if params.key?(:level) && !Bolt::Logger.valid_level?(params[:level])
          raise Bolt::CLIError,
                "level of log #{name} must be one of: #{Bolt::Logger.levels.join(', ')}; received #{params[:level]}"
        end
        if params.key?(:append) && params[:append] != true && params[:append] != false
          raise Bolt::CLIError, "append flag of log #{name} must be a Boolean, received #{params[:append]}"
        end
      end

      unless %w[human json].include? self[:format]
        raise Bolt::CLIError, "Unsupported format: '#{self[:format]}'"
      end

      if self[:transports][:ssh][:sudo_password] && self[:transports][:ssh][:run_as].nil?
        @logger.warn("--sudo-password will not be used without specifying a " \
                     "user to escalate to with --run-as")
      end

      host_key = self[:transports][:ssh][:host_key_check]
      unless !!host_key == host_key
        raise Bolt::CLIError, 'host-key-check option must be a Boolean true or false'
      end

      ssl_flag = self[:transports][:winrm][:ssl]
      unless !!ssl_flag == ssl_flag
        raise Bolt::CLIError, 'ssl option must be a Boolean true or false'
      end

      validation_flag = self[:transports][:pcp][:"local-validation"]
      unless !!validation_flag == validation_flag
        raise Bolt::CLIError, 'local-validation option must be a Boolean true or false'
      end

      self[:transports].each_value do |v|
        timeout_value = v[:connect_timeout]
        unless timeout_value.is_a?(Integer) || timeout_value.nil?
          error_msg = "connect-timeout value must be an Integer, received #{timeout_value}:#{timeout_value.class}"
          raise Bolt::CLIError, error_msg
        end
      end
    end
  end
end
