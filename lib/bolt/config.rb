# frozen_string_literal: true

require 'etc'
require 'logging'
require 'pathname'
require_relative '../bolt/project'
require_relative '../bolt/logger'
require_relative '../bolt/util'
require_relative 'config/options'
require_relative '../bolt/validator'

module Bolt
  class UnknownTransportError < Bolt::Error
    def initialize(transport, uri = nil)
      msg = uri.nil? ? "Unknown transport #{transport}" : "Unknown transport #{transport} found for #{uri}"
      super(msg, 'bolt/unknown-transport')
    end
  end

  class Config
    include Bolt::Config::Options

    attr_reader :config_files, :data, :transports, :project, :modified_concurrency

    DEFAULTS_NAME = 'bolt-defaults.yaml'

    # The default concurrency value that is used when the ulimit is not low (i.e. < 700)
    DEFAULT_DEFAULT_CONCURRENCY = 100

    def self.default
      new(Bolt::Project.default_project, {})
    end

    def self.from_project(project, overrides = {})
      data = load_defaults.push(
        filepath: project.project_file,
        data: project.data
      )

      new(project, data, overrides)
    end

    # Builds a hash of definitions for transport configuration.
    #
    def self.transport_definitions
      INVENTORY_OPTIONS.each_with_object({}) do |(option, definition), acc|
        acc[option] = TRANSPORT_CONFIG.key?(option) ? definition.merge(TRANSPORT_CONFIG[option].schema) : definition
      end
    end

    # Builds the schema for bolt-defaults.yaml used by the validator.
    #
    def self.defaults_schema
      schema = {
        type:        Hash,
        properties:  DEFAULTS_OPTIONS.map { |opt| [opt, _ref: opt] }.to_h,
        definitions: OPTIONS.merge(transport_definitions)
      }

      schema[:definitions]['inventory-config'][:properties] = transport_definitions

      schema
    end

    def self.system_path
      if Bolt::Util.windows?
        Pathname.new(File.join(ENV['ALLUSERSPROFILE'], 'PuppetLabs', 'bolt', 'etc'))
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
    # projects. This file does not allow project-specific configuration such as 'hiera-config'
    # and nests all default inventory configuration under an 'inventory-config' key.
    def self.load_bolt_defaults_yaml(dir)
      filepath     = dir + DEFAULTS_NAME
      data         = Bolt::Util.read_yaml_hash(filepath, 'config')

      Bolt::Logger.debug("Loaded configuration from #{filepath}")

      # Validate the config against the schema. This will raise a single error
      # with all validation errors.
      Bolt::Validator.new.tap do |validator|
        validator.validate(data, defaults_schema, filepath)
        validator.warnings.each { |warning| Bolt::Logger.warn(warning[:id], warning[:msg]) }
        validator.deprecations.each { |dep| Bolt::Logger.deprecate(dep[:id], dep[:msg]) }
      end

      # Remove project-specific config such as hiera-config, etc.
      project_config = data.slice(*(PROJECT_OPTIONS - DEFAULTS_OPTIONS))

      if project_config.any?
        data.reject! { |key, _| project_config.include?(key) }

        Bolt::Logger.warn(
          "unsupported_project_config",
          "Unsupported project configuration detected in '#{filepath}': #{project_config.keys}. "\
          "Project configuration should be set in 'bolt-project.yaml'."
        )
      end

      # Remove top-level transport config such as transport, ssh, etc.
      transport_config = data.slice(*INVENTORY_OPTIONS.keys)

      if transport_config.any?
        data.reject! { |key, _| transport_config.include?(key) }

        Bolt::Logger.warn(
          "unsupported_inventory_config",
          "Unsupported inventory configuration detected in '#{filepath}': #{transport_config.keys}. "\
          "Transport configuration should be set under the 'inventory-config' option or "\
          "in 'inventory.yaml'."
        )
      end

      # Move data under inventory-config to top-level so it can be easily merged with
      # config from other sources. Error early if inventory-config is not a hash or
      # has a plugin reference.
      if data.key?('inventory-config')
        unless data['inventory-config'].is_a?(Hash)
          raise Bolt::ValidationError,
                "Option 'inventory-config' must be of type Hash, received #{data['inventory-config']} "\
                "#{data['inventory-config']} (file: #{filepath})"
        end

        if data['inventory-config'].key?('_plugin')
          raise Bolt::ValidationError,
                "Found unsupported key '_plugin' for option 'inventory-config'; supported keys are "\
                "'#{INVENTORY_OPTIONS.keys.join("', '")}' (file: #{filepath})"
        end

        data = data.merge(data.delete('inventory-config'))
      end

      { filepath: filepath, data: data }
    end

    def self.load_defaults
      confs = []

      # Load system-level config.
      if File.exist?(system_path + DEFAULTS_NAME)
        confs << load_bolt_defaults_yaml(system_path)
      end

      # Load user-level config if there is a homedir.
      if user_path && File.exist?(user_path + DEFAULTS_NAME)
        confs << load_bolt_defaults_yaml(user_path)
      end

      confs
    end

    def initialize(project, config_data, overrides = {})
      unless config_data.is_a?(Array)
        config_data = [{ filepath: project.project_file, data: config_data }]
      end

      @logger       = Bolt::Logger.logger(self)
      @project      = project
      @transports   = {}
      @config_files = []

      default_data = {
        'analytics'           => true,
        'apply-settings'      => {},
        'color'               => true,
        'compile-concurrency' => Etc.nprocessors,
        'concurrency'         => default_concurrency,
        'disable-warnings'    => [],
        'format'              => 'human',
        'log'                 => { 'console' => {} },
        'module-install'      => {},
        'plugin-hooks'        => {},
        'plugins'             => {},
        'puppetdb'            => {},
        'puppetdb-instances'  => {},
        'save-rerun'          => true,
        'spinner'             => true,
        'transport'           => 'ssh'
      }

      if project.path.directory?
        default_data['log']['bolt-debug.log'] = {
          'level' => 'debug',
          'append' => false
        }
      end

      loaded_data = config_data.each_with_object([]) do |data, acc|
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

      # Pull out config options. We need to add 'transport' and 'inventoryfile' as they're
      # not part of the OPTIONS hash but are valid options that can be set with CLI options
      overrides = opts.slice(*OPTIONS.keys, 'inventoryfile', 'transport', 'default_puppetdb')

      # Pull out transport config options
      TRANSPORT_CONFIG.each do |transport, config|
        overrides[transport] = opts.slice(*config.options)
      end

      overrides['trace'] = opts['trace'] if opts.key?('trace')

      # Validate the overrides that can have arbitrary values
      schema = {
        type:        Hash,
        properties:  CLI_OPTIONS.map { |opt| [opt, _ref: opt] }.to_h,
        definitions: OPTIONS.merge(INVENTORY_OPTIONS)
      }

      Bolt::Validator.new.validate(overrides.slice(*CLI_OPTIONS), schema, 'command line')

      overrides
    end

    # Merge configuration from all sources into a single hash. Precedence from lowest to highest:
    # defaults, system-wide, user-level, project-level, CLI overrides
    def merge_config_layers(*config_data)
      config_data.inject({}) do |acc, config|
        acc.merge(config) do |key, val1, val2|
          case key
          # Shallow merge config for each plugin
          when 'plugins'
            val1.merge(val2) { |_, v1, v2| v1.merge(v2) }
          # Transports are deep merged
          when *TRANSPORT_CONFIG.keys
            Bolt::Util.deep_merge(val1, val2)
          # Hash values are shallow merged
          when 'apply-settings', 'log', 'plugin-hooks', 'puppetdb', 'puppetdb-instances'
            val1.merge(val2)
          # Disabled warnings are concatenated
          when 'disable-warnings'
            val1.concat(val2)
          when 'analytics'
            val1 && val2
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
      %w[apply-settings module-install].each do |opt|
        @data[opt] = @data[opt].slice(*OPTIONS.dig(opt, :properties).keys)
      end
    end

    private def normalize_log(target)
      return target if target == 'console'
      target = target[5..-1] if target.start_with?('file:')
      'file:' + File.expand_path(target, @project.path)
    end

    private def update_logs(logs)
      begin
        if logs['bolt-debug.log'] && logs['bolt-debug.log'] != 'disable'
          FileUtils.touch(File.expand_path('bolt-debug.log', @project.path))
        end
      rescue StandardError
        logs.delete('bolt-debug.log')
      end

      logs.each_with_object({}) do |(key, val), acc|
        # Remove any disabled logs
        next if val == 'disable'

        name = normalize_log(key)
        acc[name] = val.slice('append', 'level').transform_keys(&:to_sym)
      end
    end

    def validate
      if @data['modulepath']&.include?(@project.managed_moduledir.to_s)
        raise Bolt::ValidationError,
              "Found invalid path in modulepath: #{@project.managed_moduledir}. This path "\
              "is automatically appended to the modulepath and cannot be configured."
      end

      compile_limit = 2 * Etc.nprocessors
      unless compile_concurrency < compile_limit
        raise Bolt::ValidationError, "Compilation is CPU-intensive, set concurrency less than #{compile_limit}"
      end

      %w[hiera-config trusted-external-command inventoryfile].each do |opt|
        Bolt::Util.validate_file(opt, @data[opt]) if @data[opt]
      end

      if File.exist?(default_inventoryfile)
        Bolt::Util.validate_file('inventory file', default_inventoryfile)
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
      @project.puppetfile
    end

    def modulepath
      (@data['modulepath'] || @project.modulepath) + [@project.managed_moduledir.to_s]
    end

    def modulepath=(value)
      @data['modulepath'] = Array(value)
    end

    def plugin_cache
      @project.plugin_cache || @data['plugin-cache'] || {}
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

    def future
      @data['future']
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

    def puppetdb_instances
      @data['puppetdb-instances']
    end

    def default_puppetdb
      @data['default_puppetdb']
    end

    def color
      @data['color']
    end

    def save_rerun
      @data['save-rerun']
    end

    def spinner
      @data['spinner']
    end

    def stream
      @data['stream']
    end

    def inventoryfile
      @data['inventoryfile']
    end

    def compile_concurrency
      @data['compile-concurrency']
    end

    def plugins
      @data['plugins']
    end

    def plugin_hooks
      @data['plugin-hooks']
    end

    def policies
      @data['policies']
    end

    def trusted_external
      @data['trusted-external-command']
    end

    def apply_settings
      @data['apply-settings']
    end

    def transport
      @data['transport']
    end

    def module_install
      @project.module_install || @data['module-install']
    end

    def disable_warnings
      Set.new(@project.disable_warnings + @data['disable-warnings'])
    end

    def analytics
      @data['analytics']
    end

    # Check if there is a case-insensitive match to the path
    def check_path_case(type, paths)
      return if paths.nil?
      matches = matching_paths(paths)

      if matches.any?
        msg = "WARNING: Bolt is case sensitive when specifying a #{type}. Did you mean:\n"
        matches.each { |path| msg += "         #{path}\n" }
        Bolt::Logger.warn("path_case", msg)
      end
    end

    def matching_paths(paths)
      Array(paths).map { |p| Dir.glob([p, casefold(p)]) }.flatten.uniq.reject { |p| Array(paths).include?(p) }
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
