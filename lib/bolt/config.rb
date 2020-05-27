# frozen_string_literal: true

require 'etc'
require 'logging'
require 'pathname'
require 'bolt/project'
require 'bolt/logger'
require 'bolt/util'
# Transport config objects
require 'bolt/config/transport/ssh'
require 'bolt/config/transport/winrm'
require 'bolt/config/transport/orch'
require 'bolt/config/transport/local'
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
    attr_reader :config_files, :warnings, :data, :transports, :project

    TRANSPORT_CONFIG = {
      'ssh'    => Bolt::Config::Transport::SSH,
      'winrm'  => Bolt::Config::Transport::WinRM,
      'pcp'    => Bolt::Config::Transport::Orch,
      'local'  => Bolt::Config::Transport::Local,
      'docker' => Bolt::Config::Transport::Docker,
      'remote' => Bolt::Config::Transport::Remote
    }.freeze

    TRANSPORT_OPTION = { 'transport' => 'The default transport to use when the '\
                         'transport for a target is not specified in the URL.' }.freeze

    DEFAULT_TRANSPORT_OPTION = { 'transport' => 'ssh' }.freeze

    CONFIG_IN_INVENTORY = TRANSPORT_CONFIG.merge(TRANSPORT_OPTION)

    # NOTE: All configuration options should have a corresponding schema property
    #       in schemas/bolt-config.schema.json
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
      "transport"                => "The default transport to use when the transport for a target is not specified "\
                                    "in the URL or inventory.",
      "trusted-external-command" => "The path to an executable on the Bolt controller that can produce "\
                                    "external trusted facts. **External trusted facts are experimental in both "\
                                    "Puppet and Bolt and this API may change or be removed.**"
    }.freeze

    DEFAULT_OPTIONS = {
      "color" => true,
      "compile-concurrency" => "Number of cores",
      "concurrency" => "100 or one-third of the ulimit, whichever is lower",
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

      data = { filepath: project.config_file, data: conf }

      data = load_defaults(project).push(data).select { |config| config[:data]&.any? }

      new(project, data, overrides)
    end

    def self.from_file(configfile, overrides = {})
      project = Bolt::Project.create_project(Pathname.new(configfile).expand_path.dirname)
      conf = if project.project_file == project.config_file
               project.data
             else
               Bolt::Util.read_yaml_hash(configfile, 'config')
             end
      data = { filepath: project.config_file, data: conf }
      data = load_defaults(project).push(data).select { |config| config[:data]&.any? }

      new(project, data, overrides)
    end

    def self.load_defaults(project)
      # Lazy-load expensive gem code
      require 'win32/dir' if Bolt::Util.windows?

      # Don't load /etc/puppetlabs/bolt/bolt.yaml twice
      confs = if project.path == Bolt::Project.system_path
                []
              else
                system_path = Pathname.new(File.join(Bolt::Project.system_path, 'bolt.yaml'))
                [{ filepath: system_path, data: Bolt::Util.read_optional_yaml_hash(system_path, 'config') }]
              end

      user_path = begin
                    Pathname.new(File.expand_path(File.join('~', '.puppetlabs', 'etc', 'bolt', 'bolt.yaml')))
                  rescue ArgumentError
                    nil
                  end

      confs << { filepath: user_path, data: Bolt::Util.read_optional_yaml_hash(user_path, 'config') } if user_path
      confs
    end

    def initialize(project, config_data, overrides = {})
      unless config_data.is_a?(Array)
        config_data = [{ filepath: project.config_file, data: config_data }]
      end

      @logger = Logging.logger[self]
      @project = project
      @warnings = @project.warnings.dup
      @transports = {}
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

      loaded_data = config_data.map do |config|
        @config_files.push(config[:filepath])
        config[:data]
      end

      override_data = normalize_overrides(overrides)

      # If we need to lower concurrency and concurrency is not configured
      ld_concurrency = loaded_data.map(&:keys).flatten.include?('concurrency')
      if default_concurrency != DEFAULT_DEFAULT_CONCURRENCY &&
         !ld_concurrency &&
         !override_data.key?('concurrency')
        concurrency_warning = { option: 'concurrency',
                                msg: "Concurrency will default to #{default_concurrency} because ulimit "\
                                "is low: #{Etc.sysconf(Etc::SC_OPEN_MAX)}. Set concurrency with "\
                                "'--concurrency', or set your ulimit with 'ulimit -n <limit>'" }
        @warnings << concurrency_warning
      end

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

      # Pull out config options
      overrides = opts.slice(*OPTIONS.keys)

      # Pull out transport config options
      TRANSPORT_CONFIG.each do |transport, config|
        overrides[transport] = opts.slice(*config.options.keys)
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
      @data['apply_settings'] = @data['apply_settings'].slice(*APPLY_SETTINGS.keys)
      @data['puppetfile'] = @data['puppetfile'].slice(*PUPPETFILE_OPTIONS.keys)
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
        acc[name] = val.slice(*LOG_OPTIONS.keys)
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

      unless %w[human json].include? format
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
                                 Etc.sysconf(Etc::SC_OPEN_MAX) / 3
                               end
    end
  end
end
