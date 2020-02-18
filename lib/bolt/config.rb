# frozen_string_literal: true

require 'etc'
require 'logging'
require 'pathname'
require 'bolt/boltdir'
require 'bolt/logger'
require 'bolt/util'
# Transport config objects
require 'bolt/config/transport/ssh'
require 'bolt/config/transport/winrm'
require 'bolt/config/transport/orch'
require 'bolt/config/transport/local'
require 'bolt/config/transport/local_windows'
require 'bolt/config/transport/docker'
require 'bolt/config/transport/remote'

module Bolt
  class UnknownTransportError < Bolt::Error
    def initialize(transport, uri = nil)
      msg = uri.nil? ? "Unknown transport #{transport}" : "Unknown transport #{transport} found for #{uri}"
      super(msg, 'bolt/unknown-transport')
    end
  end

  class Config
    attr_reader :config_files, :warnings, :data, :transports, :boltdir

    TRANSPORT_CONFIG = {
      'ssh'    => Bolt::Config::SSH,
      'winrm'  => Bolt::Config::WinRM,
      'pcp'    => Bolt::Config::Orch,
      'local'  => Bolt::Util.windows? ? Bolt::Config::LocalWindows : Bolt::Config::Local,
      'docker' => Bolt::Config::Docker,
      'remote' => Bolt::Config::Remote
    }.freeze

    OPTIONS = {
      "apply_settings"           => "A map of Puppet settings to use when applying Puppet code",
      "color"                    => "Whether to use colored output when printing messages to the console.",
      "compile-concurrency"      => "The maximum number of simultaneous manifest block compiles.",
      "concurrency"              => "The number of threads to use when executing on remote targets.",
      "format"                   => "The format to use when printing results. Options are `human` and `json`.",
      "hiera-config"             => "The path to your Hiera config.",
      "inventoryfile"            => "The path to a structured data inventory file used to refer to groups of "\
                                    "targets on the command line and from plans.",
      "log"                      => "The configuration of the logfile output. Configuration can be set for "\
                                    "`console` and the path to a log file, such as `~/.puppetlabs/bolt/debug.log`.",
      "modulepath"               => "The module path for loading tasks and plan code. This is either an array "\
                                    "of directories or a string containing a list of directories separated by the "\
                                    "OS-specific PATH separator.",
      "plugin_hooks"             => "Which plugins a specific hook should use.",
      "plugins"                  => "A map of plugins and their configuration data.",
      "puppetdb"                 => "A map containing options for configuring the Bolt PuppetDB client.",
      "puppetfile"               => "A map containing options for the `bolt puppetfile install` command.",
      "save-rerun"               => "Whether to update `.rerun.json` in the Bolt project directory. If "\
                                    "your target names include passwords, set this value to `false` to avoid "\
                                    "writing passwords to disk.",
      "transport"                => "The default transport to use when the transport for a target is not "\
                                    "specified in the URL or inventory.",
      "trusted-external-command" => "The path to an executable on the Bolt controller that can produce "\
                                    "external trusted facts. **External trusted facts are experimental in both "\
                                    "Puppet and Bolt and this API may change or be removed.**"
    }.freeze

    DEFAULT_OPTIONS = {
      "color" => true,
      "concurrency" => 100,
      "compile-concurrency" => "Number of cores",
      "format" => "human",
      "hiera-config" => "Boltdir/hiera.yaml",
      "inventoryfile" => "Boltdir/inventory.yaml",
      "modulepath" => ["Boltdir/modules", "Boltdir/site-modules", "Boltdir/site"],
      "save-rerun" => true
    }.freeze

    PUPPETFILE_OPTIONS = {
      "forge" => "A subsection that can have its own `proxy` setting to set an HTTP proxy for Forge operations "\
                 "only, and a `baseurl` setting to specify a different Forge host.",
      "proxy" => "The HTTP proxy to use for Git and Forge operations."
    }.freeze

    LOG_OPTIONS = {
      "append" => "Add output to an existing log file. Available only for logs output to a "\
                  "filepath.",
      "level"  => "The type of information in the log. Either `debug`, `info`, `notice`, "\
                  "`warn`, or `error`."
    }.freeze

    DEFAULT_LOG_OPTIONS = {
      "append" => true,
      "level"  => "`warn` for console, `notice` for file"
    }.freeze

    APPLY_SETTINGS = {
      "show_diff" => "Whether to log and report a contextual diff when files are being replaced. "\
                     "See [Puppet documentation](https://puppet.com/docs/puppet/latest/configuration.html#showdiff) "\
                     "for details"
    }.freeze

    DEFAULT_APPLY_SETTINGS = {
      "show_diff" => false
    }.freeze

    def self.default
      new(Bolt::Boltdir.new('.'), {})
    end

    def self.from_boltdir(boltdir, overrides = {})
      data = {
        filepath: boltdir.config_file,
        data: Bolt::Util.read_optional_yaml_hash(boltdir.config_file, 'config')
      }

      data = load_defaults.push(data).select { |config| config[:data]&.any? }

      new(boltdir, data, overrides)
    end

    def self.from_file(configfile, overrides = {})
      boltdir = Bolt::Boltdir.new(Pathname.new(configfile).expand_path.dirname)

      data = {
        filepath: boltdir.config_file,
        data: Bolt::Util.read_yaml_hash(configfile, 'config')
      }
      data = load_defaults.push(data).select { |config| config[:data]&.any? }

      new(boltdir, data, overrides)
    end

    def self.load_defaults
      # Lazy-load expensive gem code
      require 'win32/dir' if Bolt::Util.windows?

      system_path = if Bolt::Util.windows?
                      Pathname.new(File.join(Dir::COMMON_APPDATA, 'PuppetLabs', 'bolt', 'etc', 'bolt.yaml'))
                    else
                      Pathname.new(File.join('/etc', 'puppetlabs', 'bolt', 'bolt.yaml'))
                    end
      user_path = Pathname.new(File.expand_path(File.join('~', '.puppetlabs', 'etc', 'bolt', 'bolt.yaml')))

      [{ filepath: system_path, data: Bolt::Util.read_optional_yaml_hash(system_path, 'config') },
       { filepath: user_path, data: Bolt::Util.read_optional_yaml_hash(user_path, 'config') }]
    end

    def initialize(boltdir, config_data, overrides = {})
      unless config_data.is_a?(Array)
        config_data = [{ filepath: boltdir.config_file, data: config_data }]
      end

      @logger = Logging.logger[self]
      @warnings = []
      @boltdir = boltdir
      @transports = {}
      @config_files = []

      default_data = {
        'apply_settings'      => {},
        'color'               => true,
        'compile-concurrency' => Etc.nprocessors,
        'concurrency'         => 100,
        'format'              => 'human',
        'log'                 => { 'console' => {} },
        'plugin_hooks'        => {},
        'plugins'             => {},
        'puppetdb'            => {},
        'puppetfile'          => {},
        'save-rerun'          => true,
        'transport'           => 'ssh'
      }

      loaded_data = config_data.map do |config|
        @config_files.push(config[:filepath])
        config[:data]
      end

      override_data = transform_overrides(overrides)

      @data = merge_config_data(default_data, *loaded_data, override_data)

      TRANSPORT_CONFIG.each do |transport, config|
        @transports[transport] = config.new(@data.delete(transport), @boltdir.path)
      end

      update_data
      validate
    end

    # Transforms CLI options into a config hash that can be merged with
    # default and loaded config.
    def transform_overrides(options)
      opts = options.dup.transform_keys(&:to_s)

      # Pull out config options
      overrides = opts.slice(*OPTIONS.keys)

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

    # Merge configuration from all sources into a single hash
    # Precedence from highest to lowest is: CLI overrides, project, user-level, system-wide, defaults
    def merge_config_data(*config_data)
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

    def transport_data_get
      { transport: transport, transports: transports }
    end

    def deep_clone
      Bolt::Util.deep_clone(self)
    end

    private def update_data
      if @data['log'].is_a?(Hash)
        @data['log'] = update_logs(@data['log'])
      end

      # Expand paths relative to the Boltdir. Any settings that came from the
      # CLI will already be absolute, so the expand will be skipped.
      if @data.key?('modulepath')
        moduledirs = if data['modulepath'].is_a?(String)
                       data['modulepath'].split(File::PATH_SEPARATOR)
                     else
                       data['modulepath']
                     end
        @data['modulepath'] = moduledirs.map do |moduledir|
          File.expand_path(moduledir, @boltdir.path)
        end
      end

      %w[hiera-config inventoryfile trusted-external-command].each do |opt|
        @data[opt] = File.expand_path(@data[opt], @boltdir.path) if @data[opt]
      end

      # Filter hashes to only include valid options
      @data['apply_settings'] = @data['apply_settings'].slice(*APPLY_SETTINGS.keys)
      @data['puppetfile'] = @data['puppetfile'].slice(*PUPPETFILE_OPTIONS.keys)
    end

    private def normalize_log(target)
      return target if target == 'console'
      target = target[5..-1] if target.start_with?('file:')
      'file:' + File.expand_path(target, @boltdir.path)
    end

    private def update_logs(logs)
      logs.each_with_object({}) do |(key, val), acc|
        next unless val.is_a?(Hash)

        name = normalize_log(key)
        acc[name] = val.slice(*LOG_OPTIONS.keys)
                       .transform_keys(&:to_sym)

        if (v = acc[name][:level])
          unless Bolt::Logger.valid_level?(v)
            raise Bolt::ValidationError,
                  "level of log #{name} must be one of #{Bolt::Logger.levels.join(', ')}; received #{v}"
          end
          unless v.is_a?(String) || v.is_a?(Symbol)
            raise Bolt::ValidationError,
                  "level of log #{name} must be a String or Symbol, received #{v.class} #{v.inspect}"
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

      keys = OPTIONS.keys - %w[plugins plugin_hooks]
      keys.each do |key|
        next unless references?(@data[key])
        valid_keys = TRANSPORT_CONFIG.keys + %w[plugins plugin_hooks]
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

      unless %w[human json].include? format
        raise Bolt::ValidationError, "Unsupported format: '#{format}'"
      end

      Bolt::Util.validate_file('hiera-config', @data['hiera_config']) if @data['hiera_config']
      Bolt::Util.validate_file('trusted-external-command', trusted_external) if trusted_external

      unless TRANSPORT_CONFIG.include?(transport)
        raise UnknownTransportError, transport
      end
    end

    # Recursively searches a data structure for plugin references
    private def references?(input)
      reference = false
      if input.is_a?(Hash)
        reference = input.key?('_plugin')
        input.each_value { |v| reference ||= references?(v) }
      elsif input.is_a?(Array)
        input.each { |v| reference ||= references?(v) }
      end
      reference
    end

    def default_inventoryfile
      @boltdir.inventory_file
    end

    def rerunfile
      @boltdir.rerunfile
    end

    def hiera_config
      @data['hiera-config'] || @boltdir.hiera_config
    end

    def puppetfile
      @puppetfile || @boltdir.puppetfile
    end

    def modulepath
      @data['modulepath'] || @boltdir.modulepath
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
  end
end
