require 'logger'
require 'yaml'
require 'bolt/cli'

module Bolt
  Config = Struct.new(
    :concurrency,
    :format,
    :log_destination,
    :log_level,
    :modulepath,
    :transport,
    :transports
  ) do

    DEFAULTS = {
      concurrency: 100,
      transport: 'ssh',
      format: 'human',
      log_level: Logger::WARN,
      log_destination: STDERR
    }.freeze

    TRANSPORT_OPTIONS = %i[insecure password run_as sudo_password
                           key tty tmpdir user connect_timeout cacert
                           token_file orch_task_environment service_url].freeze

    TRANSPORT_DEFAULTS = {
      connect_timeout: 10,
      orch_task_environment: 'production',
      insecure: false,
      tty: false
    }.freeze

    TRANSPORTS = %i[ssh winrm pcp].freeze

    def initialize(**kwargs)
      super()
      DEFAULTS.merge(kwargs).each { |k, v| self[k] = v }

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
      end
    end

    def default_paths
      root_path = File.expand_path(File.join('~', '.puppetlabs'))
      [File.join(root_path, 'bolt.yaml'), File.join(root_path, 'bolt.yml')]
    end

    def read_config_file(path)
      path_passed = path
      if path.nil?
        found_default = default_paths.select { |p| File.exist?(p) }
        if found_default.size > 1
          logger = Logger.new(self[:log_destination])
          logger.warn "Config files found at #{found_default.join(', ')}, using the first"
        end
        # Use first found, fall back to first default and try to load even if it didn't exist
        path = found_default.first || default_paths.first
      end

      path = File.expand_path(path)
      # safe_load doesn't work with psych in ruby 2.0
      # The user controls the configfile so this isn't a problem
      # rubocop:disable YAMLLoad
      File.open(path, "r:UTF-8") { |f| YAML.load(f.read) }
    rescue Errno::ENOENT
      if path_passed
        raise Bolt::CLIError, "Could not read config file: #{path}"
      end
    # In older releases of psych SyntaxError is not a subclass of Exception
    rescue Psych::SyntaxError
      raise Bolt::CLIError, "Could not parse config file: #{path}"
    rescue Psych::Exception
      raise Bolt::CLIError, "Could not parse config file: #{path}"
    rescue IOError, SystemCallError
      raise Bolt::CLIError, "Could not read config file: #{path}"
    end

    def update_from_file(data)
      if data['modulepath']
        self[:modulepath] = data['modulepath'].split(File::PATH_SEPARATOR)
      end

      if data['concurrency']
        self[:concurrency] = data['concurrency']
      end

      if data['format']
        self[:format] = data['format'] if data['format']
      end

      if data['ssh']
        if data['ssh']['private-key']
          self[:transports][:ssh][:key] = data['ssh']['private-key']
        end
        if data['ssh']['insecure']
          self[:transports][:ssh][:insecure] = data['ssh']['insecure']
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
        if data['winrm']['insecure']
          self[:transports][:winrm][:insecure] = data['winrm']['insecure']
        end
        if data['winrm']['tmpdir']
          self[:transports][:winrm][:tmpdir] = data['winrm']['tmpdir']
        end
        if data['winrm']['cacert']
          self[:transports][:winrm][:cacert] = data['winrm']['cacert']
        end
      end

      if data['pcp']
        if data['pcp']['service-url']
          self[:transports][:pcp][:service_url] = data['pcp']['service-url']
        end
        if data['pcp']['cacert']
          self[:transports][:pcp][:cacert] = data['pcp']['cacert']
        end
        if data['pcp']['token-file']
          self[:transports][:pcp][:token_file] = data['pcp']['token-file']
        end
        if data['pcp']['task-environment']
          self[:transports][:pcp][:orch_task_environment] = data['pcp']['task-environment']
        end
      end
    end

    def load_file(path)
      data = read_config_file(path)
      update_from_file(data) if data
    end

    def update_from_cli(options)
      %i[concurrency transport format modulepath ssh['run_as']].each do |key|
        self[key] = options[key] if options[key]
      end

      if options[:debug]
        self[:log_level] = Logger::DEBUG
      elsif options[:verbose]
        self[:log_level] = Logger::INFO
      end

      TRANSPORT_OPTIONS.each do |key|
        # TODO: We should eventually make these transport specific
        TRANSPORTS.each do |transport|
          self[:transports][transport][key] = options[key] if options[key]
        end
      end
    end

    def validate
      TRANSPORTS.each do |transport|
        self[:transports][transport]
      end

      unless %w[human json].include? self[:format]
        raise Bolt::CLIError, "Unsupported format: '#{self[:format]}'"
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
