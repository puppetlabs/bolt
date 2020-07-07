# frozen_string_literal: true

require 'etc'
require 'logging'
require 'pathname'
require 'bolt/project'
require 'bolt/logger'
require 'bolt/util'
require 'bolt/config/options'

module Bolt
  class UnknownTransportError < Bolt::Error
    def initialize(transport, uri = nil)
      msg = uri.nil? ? "Unknown transport #{transport}" : "Unknown transport #{transport} found for #{uri}"
      super(msg, 'bolt/unknown-transport')
    end
  end

  class Config
    include Bolt::Config::Options

    attr_reader :config_files, :warnings, :data, :transports, :project, :modified_concurrency

    BOLT_CONFIG_NAME = 'bolt.yaml'
    BOLT_DEFAULTS_NAME = 'bolt-defaults.yaml'

    # The default concurrency value that is used when the ulimit is not low (i.e. < 700)
    DEFAULT_DEFAULT_CONCURRENCY = 100

    def self.default
      new(Bolt::Project.create_project('.'), {})
    end

    def self.from_project(project, overrides = {})
      conf = if project.project_file == project.config_file
               project.data
             else
               Bolt::Util.read_optional_yaml_hash(project.config_file, 'config')
             end

      data = load_defaults(project).push(
        filepath: project.config_file,
        data: conf,
        warnings: []
      )

      new(project, data, overrides)
    end

    def self.from_file(configfile, overrides = {})
      project = Bolt::Project.create_project(Pathname.new(configfile).expand_path.dirname)

      conf = if project.project_file == project.config_file
               project.data
             else
               Bolt::Util.read_yaml_hash(configfile, 'config')
             end

      data = load_defaults(project).push(
        filepath: project.config_file,
        data: conf,
        warnings: []
      )

      new(project, data, overrides)
    end

    def self.system_path
      # Lazy-load expensive gem code
      require 'win32/dir' if Bolt::Util.windows?

      if Bolt::Util.windows?
        Pathname.new(File.join(Dir::COMMON_APPDATA, 'PuppetLabs', 'bolt', 'etc'))
      else
        Pathname.new(File.join('/etc', 'puppetlabs', 'bolt'))
      end
    end

    def self.user_path
      Pathname.new(File.expand_path(File.join('~', '.puppetlabs', 'etc', 'bolt')))
    rescue StandardError
      nil
    end

    # Loads a 'bolt-defaults.yaml' file, which contains default configuration that applies to all
    # projects. This file does not allow project-specific configuration such as 'hiera-config' and
    # 'inventoryfile', and nests all default inventory configuration under an 'inventory-config' key.
    def self.load_bolt_defaults_yaml(dir)
      filepath = dir + BOLT_DEFAULTS_NAME
      data     = Bolt::Util.read_yaml_hash(filepath, 'config')
      warnings = []

      # Warn if 'bolt.yaml' detected in same directory.
      if File.exist?(bolt_yaml = dir + BOLT_CONFIG_NAME)
        warnings.push(
          msg: "Detected multiple configuration files: ['#{bolt_yaml}', '#{filepath}']. '#{bolt_yaml}' "\
               "will be ignored."
        )
      end

      # Remove project-specific config such as hiera-config, etc.
      project_config = data.slice(*(BOLT_PROJECT_OPTIONS - BOLT_DEFAULTS_OPTIONS))

      if project_config.any?
        data.reject! { |key, _| project_config.include?(key) }
        warnings.push(
          msg: "Unsupported project configuration detected in '#{filepath}': #{project_config.keys}. "\
                "Project configuration should be set in 'bolt-project.yaml'."
        )
      end

      # Remove top-level transport config such as transport, ssh, etc.
      transport_config = data.slice(*INVENTORY_OPTIONS.keys)

      if transport_config.any?
        data.reject! { |key, _| transport_config.include?(key) }
        warnings.push(
          msg: "Unsupported inventory configuration detected in '#{filepath}': #{transport_config.keys}. "\
               "Transport configuration should be set under the 'inventory-config' option or "\
               "in 'inventory.yaml'."
        )
      end

      # Move data under transport-config to top-level so it can be easily merged with
      # config from other sources.
      if data.key?('inventory-config')
        data = data.merge(data.delete('inventory-config'))
      end

      { filepath: filepath, data: data, warnings: warnings }
    end

    # Loads a 'bolt.yaml' file, the legacy configuration file. There's no special munging needed
    # here since Bolt::Config will just ignore any invalid keys.
    def self.load_bolt_yaml(dir)
      filepath = dir + BOLT_CONFIG_NAME
      data     = Bolt::Util.read_yaml_hash(filepath, 'config')
      warnings = [msg: "Configuration file #{filepath} is deprecated and will be removed in a future version "\
                        "of Bolt. Use '#{dir + BOLT_DEFAULTS_NAME}' instead."]

      { filepath: filepath, data: data, warnings: warnings }
    end

    def self.load_defaults(project)
      confs = []

      # Load system-level config. Prefer a 'bolt-defaults.yaml' file, but fall back to the
      # legacy 'bolt.yaml' file. If the project-level config file is also the system-level
      # config file, don't load it a second time.
      if File.exist?(system_path + BOLT_DEFAULTS_NAME)
        confs << load_bolt_defaults_yaml(system_path)
      elsif File.exist?(system_path + BOLT_CONFIG_NAME) &&
            (system_path + BOLT_CONFIG_NAME) != project.config_file
        confs << load_bolt_yaml(system_path)
      end

      # Load user-level config if there is a homedir. Prefer a 'bolt-defaults.yaml' file, but
      # fall back to the legacy 'bolt.yaml' file.
      if user_path
        if File.exist?(user_path + BOLT_DEFAULTS_NAME)
          confs << load_bolt_defaults_yaml(user_path)
        elsif File.exist?(user_path + BOLT_CONFIG_NAME)
          confs << load_bolt_yaml(user_path)
        end
      end

      confs
    end

    def initialize(project, config_data, overrides = {})
      unless config_data.is_a?(Array)
        config_data = [{ filepath: project.config_file, data: config_data, warnings: [] }]
      end

      @logger       = Logging.logger[self]
      @project      = project
      @warnings     = @project.warnings.dup
      @transports   = {}
      @config_files = []

      default_data = {
        'apply_settings'      => {},
        'color'               => true,
        'compile-concurrency' => Etc.nprocessors,
        'concurrency'         => default_concurrency,
        'format'              => 'human',
        'log'                 => { 'console' => {} },
        'plugin_hooks'        => {},
        'plugins'             => {},
        'puppetdb'            => {},
        'puppetfile'          => {},
        'save-rerun'          => true,
        'transport'           => 'ssh'
      }

      loaded_data = config_data.each_with_object([]) do |data, acc|
        @warnings.concat(data[:warnings]) if data[:warnings].any?

        if data[:data].any?
          @config_files.push(data[:filepath])
          acc.push(data[:data])
        end
      end

      override_data = normalize_overrides(overrides)

      # If we need to lower concurrency and concurrency is not configured
      ld_concurrency = loaded_data.map(&:keys).flatten.include?('concurrency')
      @modified_concurrency = default_concurrency != DEFAULT_DEFAULT_CONCURRENCY &&
                              !ld_concurrency &&
                              !override_data.key?('concurrency')

      @data = merge_config_layers(default_data, *loaded_data, override_data)

      TRANSPORT_CONFIG.each do |transport, config|
        @transports[transport] = config.new(@data.delete(transport), @project.path)
      end

      finalize_data
      validate
    end

    # Transforms CLI options into a config hash that can be merged with
    # default and loaded config.
    def normalize_overrides(options)
      opts = options.transform_keys(&:to_s)

      # Pull out config options. We need to add 'transport' as it's not part of the
      # OPTIONS hash but is a valid option that can be set with the --transport CLI option
      overrides = opts.slice(*OPTIONS.keys, 'transport')

      # Pull out transport config options
      TRANSPORT_CONFIG.each do |transport, config|
        overrides[transport] = opts.slice(*config.options)
      end

      # Set console log to debug if in debug mode
      if options[:debug]
        overrides['log'] = { 'console' => { 'level' => :debug } }
      end

      if options[:puppetfile_path]
        @puppetfile = options[:puppetfile_path]
      end

      overrides['trace'] = opts['trace'] if opts.key?('trace')

      overrides
    end

    # Merge configuration from all sources into a single hash. Precedence from lowest to highest:
    # defaults, system-wide, user-level, project-level, CLI overrides
    def merge_config_layers(*config_data)
      config_data.inject({}) do |acc, config|
        acc.merge(config) do |key, val1, val2|
          case key
          # Plugin config is shallow merged for each plugin
          when 'plugins'
            val1.merge(val2) { |_, v1, v2| v1.merge(v2) }
          # Transports are deep merged
          when *TRANSPORT_CONFIG.keys
            Bolt::Util.deep_merge(val1, val2)
          # Hash values are shallow merged
          when 'puppetdb', 'plugin_hooks', 'apply_settings', 'log'
            val1.merge(val2)
          # All other values are overwritten
          else
            val2
          end
        end
      end
    end

    def deep_clone
      Bolt::Util.deep_clone(self)
    end

    private def finalize_data
      if @data['log'].is_a?(Hash)
        @data['log'] = update_logs(@data['log'])
      end

      # Expand paths relative to the project. Any settings that came from the
      # CLI will already be absolute, so the expand will be skipped.
      if @data.key?('modulepath')
        moduledirs = if data['modulepath'].is_a?(String)
                       data['modulepath'].split(File::PATH_SEPARATOR)
                     else
                       data['modulepath']
                     end
        @data['modulepath'] = moduledirs.map do |moduledir|
          File.expand_path(moduledir, @project.path)
        end
      end

      %w[hiera-config inventoryfile trusted-external-command].each do |opt|
        @data[opt] = File.expand_path(@data[opt], @project.path) if @data.key?(opt)
      end

      # Filter hashes to only include valid options
      @data['apply_settings'] = @data['apply_settings'].slice(*OPTIONS['apply_settings'][:properties].keys)
      @data['puppetfile'] = @data['puppetfile'].slice(*OPTIONS['puppetfile'][:properties].keys)
    end

    private def normalize_log(target)
      return target if target == 'console'
      target = target[5..-1] if target.start_with?('file:')
      'file:' + File.expand_path(target, @project.path)
    end

    private def update_logs(logs)
      logs.each_with_object({}) do |(key, val), acc|
        next unless val.is_a?(Hash)

        name = normalize_log(key)
        acc[name] = val.slice('append', 'level')
                       .transform_keys(&:to_sym)

        if (v = acc[name][:level])
          unless v.is_a?(String) || v.is_a?(Symbol)
            raise Bolt::ValidationError,
                  "level of log #{name} must be a String or Symbol, received #{v.class} #{v.inspect}"
          end
          unless Bolt::Logger.valid_level?(v)
            raise Bolt::ValidationError,
                  "level of log #{name} must be one of #{Bolt::Logger.levels.join(', ')}; received #{v}"
          end
        end

        if (v = acc[name][:append]) && v != true && v != false
          raise Bolt::ValidationError,
                "append flag of log #{name} must be a Boolean, received #{v.class} #{v.inspect}"
        end
      end
    end

    def validate
      if @data['future']
        msg = "Configuration option 'future' no longer exposes future behavior."
        @warnings << { option: 'future', msg: msg }
      end

      keys = OPTIONS.keys - %w[plugins plugin_hooks puppetdb]
      keys.each do |key|
        next unless Bolt::Util.references?(@data[key])
        valid_keys = TRANSPORT_CONFIG.keys + %w[plugins plugin_hooks puppetdb]
        raise Bolt::ValidationError,
              "Found unsupported key _plugin in config setting #{key}. Plugins are only available in "\
              "#{valid_keys.join(', ')}."
      end

      unless concurrency.is_a?(Integer) && concurrency > 0
        raise Bolt::ValidationError,
              "Concurrency must be a positive Integer, received #{concurrency.class} #{concurrency}"
      end

      unless compile_concurrency.is_a?(Integer) && compile_concurrency > 0
        raise Bolt::ValidationError,
              "Compile concurrency must be a positive Integer, received #{compile_concurrency.class} "\
              "#{compile_concurrency}"
      end

      compile_limit = 2 * Etc.nprocessors
      unless compile_concurrency < compile_limit
        raise Bolt::ValidationError, "Compilation is CPU-intensive, set concurrency less than #{compile_limit}"
      end

      if (format == 'rainbow' && Bolt::Util.windows?) || !(%w[human json rainbow].include? format)
        raise Bolt::ValidationError, "Unsupported format: '#{format}'"
      end

      Bolt::Util.validate_file('hiera-config', @data['hiera-config']) if @data['hiera-config']
      Bolt::Util.validate_file('trusted-external-command', trusted_external) if trusted_external

      unless TRANSPORT_CONFIG.include?(transport)
        raise UnknownTransportError, transport
      end
    end

    def default_inventoryfile
      @project.inventory_file
    end

    def rerunfile
      @project.rerunfile
    end

    def hiera_config
      @data['hiera-config'] || @project.hiera_config
    end

    def puppetfile
      @puppetfile || @project.puppetfile
    end

    def modulepath
      @data['modulepath'] || @project.modulepath
    end

    def modulepath=(value)
      @data['modulepath'] = value
    end

    def concurrency
      @data['concurrency']
    end

    def format
      @data['format']
    end

    def format=(value)
      @data['format'] = value
    end

    def trace
      @data['trace']
    end

    def log
      @data['log']
    end

    def puppetdb
      @data['puppetdb']
    end

    def color
      @data['color']
    end

    def save_rerun
      @data['save-rerun']
    end

    def inventoryfile
      @data['inventoryfile']
    end

    def compile_concurrency
      @data['compile-concurrency']
    end

    def puppetfile_config
      @data['puppetfile']
    end

    def plugins
      @data['plugins']
    end

    def plugin_hooks
      @data['plugin_hooks']
    end

    def trusted_external
      @data['trusted-external-command']
    end

    def apply_settings
      @data['apply_settings']
    end

    def transport
      @data['transport']
    end

    # Check if there is a case-insensitive match to the path
    def check_path_case(type, paths)
      return if paths.nil?
      matches = matching_paths(paths)

      if matches.any?
        msg = "WARNING: Bolt is case sensitive when specifying a #{type}. Did you mean:\n"
        matches.each { |path| msg += "         #{path}\n" }
        @logger.warn msg
      end
    end

    def matching_paths(paths)
      [*paths].map { |p| Dir.glob([p, casefold(p)]) }.flatten.uniq.reject { |p| [*paths].include?(p) }
    end

    private def casefold(path)
      path.chars.map do |l|
        l =~ /[A-Za-z]/ ? "[#{l.upcase}#{l.downcase}]" : l
      end.join
    end

    # Etc::SC_OPEN_MAX is meaningless on windows, not defined in PE Jruby and not available
    # on some platforms. This method holds the logic to decide whether or not to even consider it.
    def sc_open_max_available?
      !Bolt::Util.windows? && defined?(Etc::SC_OPEN_MAX) && Etc.sysconf(Etc::SC_OPEN_MAX)
    end

    def default_concurrency
      @default_concurrency ||= if !sc_open_max_available? || Etc.sysconf(Etc::SC_OPEN_MAX) >= 300
                                 DEFAULT_DEFAULT_CONCURRENCY
                               else
                                 Etc.sysconf(Etc::SC_OPEN_MAX) / 7
                               end
    end
  end
end
