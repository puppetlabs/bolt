# frozen_string_literal: true

require 'etc'
require 'logging'
require 'pathname'
require 'bolt/boltdir'
require 'bolt/logger'
require 'bolt/transport/ssh'
require 'bolt/transport/winrm'
require 'bolt/transport/orch'
require 'bolt/transport/local'
require 'bolt/transport/local_windows'
require 'bolt/transport/docker'
require 'bolt/transport/remote'
require 'bolt/util'

module Bolt
  TRANSPORTS = {
    ssh: Bolt::Transport::SSH,
    winrm: Bolt::Transport::WinRM,
    pcp: Bolt::Transport::Orch,
    local: Bolt::Util.windows? ? Bolt::Transport::LocalWindows : Bolt::Transport::Local,
    docker: Bolt::Transport::Docker,
    remote: Bolt::Transport::Remote
  }.freeze

  class UnknownTransportError < Bolt::Error
    def initialize(transport, uri = nil)
      msg = uri.nil? ? "Unknown transport #{transport}" : "Unknown transport #{transport} found for #{uri}"
      super(msg, 'bolt/unknown-transport')
    end
  end

  class Config
    attr_accessor :concurrency, :format, :trace, :log, :puppetdb, :color, :save_rerun,
                  :transport, :transports, :inventoryfile, :compile_concurrency, :boltdir,
                  :puppetfile_config, :plugins, :plugin_hooks, :trusted_external,
                  :apply_settings
    attr_writer :modulepath
    attr_reader :config_files, :warnings

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

      @boltdir = boltdir
      @concurrency = 100
      @compile_concurrency = Etc.nprocessors
      @transport = 'ssh'
      @format = 'human'
      @puppetdb = {}
      @color = true
      @save_rerun = true
      @puppetfile_config = {}
      @plugins = {}
      @plugin_hooks = {}
      @apply_settings = {}
      @warnings = []

      # add an entry for the default console logger
      @log = { 'console' => {} }

      @transports = {}

      TRANSPORTS.each do |key, transport|
        @transports[key] = transport.default_options
      end

      @config_files = config_data.map { |config| config[:filepath] }
      config_data = merge_config_data(config_data)
      update_from_file(config_data)

      apply_overrides(overrides)

      validate
    end

    # Merge configuration
    # Precedence from highest to lowest is: project, user-level, system-wide
    def merge_config_data(config_data)
      config_data.inject({}) do |acc, config|
        acc.merge(config[:data]) do |key, val1, val2|
          case key
          # Plugin config is shallow merged for each plugin
          when 'plugins'
            val1.merge(val2) { |_, v1, v2| v1.merge(v2) }
          # Transports are deep merged
          when *TRANSPORTS.keys.map(&:to_s)
            Bolt::Util.deep_merge(val1, val2)
          # Hash values are shallow mergeed
          when 'puppetdb', 'plugin_hooks', 'apply_settings', 'log'
            val1.merge(val2)
          # All other values are overwritten
          else
            val2
          end
        end
      end
    end

    def overwrite_transport_data(transport, transports)
      @transport = transport
      @transports = transports
    end

    def transport_data_get
      { transport: @transport, transports: @transports }
    end

    def deep_clone
      Bolt::Util.deep_clone(self)
    end

    def normalize_log(target)
      return target if target == 'console'
      target = target[5..-1] if target.start_with?('file:')
      'file:' + File.expand_path(target, @boltdir.path)
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
      if data['future']
        msg = "Configuration option 'future' no longer exposes future behavior."
        @warnings << { option: 'future', msg: msg }
      end

      if data['log'].is_a?(Hash)
        update_logs(data['log'])
      end

      # Expand paths relative to the Boltdir. Any settings that came from the
      # CLI will already be absolute, so the expand will be skipped.
      if data.key?('modulepath')
        moduledirs = if data['modulepath'].is_a?(String)
                       data['modulepath'].split(File::PATH_SEPARATOR)
                     else
                       data['modulepath']
                     end
        @modulepath = moduledirs.map do |moduledir|
          File.expand_path(moduledir, @boltdir.path)
        end
      end

      @inventoryfile = File.expand_path(data['inventoryfile'], @boltdir.path) if data.key?('inventoryfile')

      if data.key?('puppetfile')
        @puppetfile_config = data['puppetfile'].select { |k, _| PUPPETFILE_OPTIONS.include?(k) }
      end

      @hiera_config = File.expand_path(data['hiera-config'], @boltdir.path) if data.key?('hiera-config')
      @trusted_external = if data.key?('trusted-external-command')
                            File.expand_path(data['trusted-external-command'], @boltdir.path)
                          end

      if data.key?('apply_settings')
        @apply_settings = data['apply_settings'].select { |k, _| APPLY_SETTINGS.keys.include?(k) }
      end

      @compile_concurrency = data['compile-concurrency'] if data.key?('compile-concurrency')

      @save_rerun = data['save-rerun'] if data.key?('save-rerun')

      %w[concurrency format puppetdb color plugins plugin_hooks].each do |key|
        send("#{key}=", data[key]) if data.key?(key)
      end

      update_transports(data)
    end
    private :update_from_file

    def apply_overrides(options)
      %i[concurrency transport format trace modulepath inventoryfile color].each do |key|
        send("#{key}=", options[key]) if options.key?(key)
      end

      @puppetfile = options[:puppetfile] if options.key?(:puppetfile)

      @save_rerun = options[:'save-rerun'] if options.key?(:'save-rerun')

      if options[:debug]
        @log['console'][:level] = :debug
      end

      @compile_concurrency = options[:'compile-concurrency'] if options[:'compile-concurrency']

      TRANSPORTS.each_key do |transport|
        # Get the options first since transport is modified in the next line
        transport_options = TRANSPORTS[transport]::OPTIONS.keys.map(&:to_sym)
        transport = @transports[transport]
        transport_options.each do |key|
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
      update_transports(data)
    end

    def update_transports(data)
      self.class.update_transport_hash(@boltdir.path, @transports, data)
      @transport = data['transport'] if data.key?('transport')
    end

    def self.update_transport_hash(boltdir, existing, data)
      TRANSPORTS.each do |key, impl|
        if data[key.to_s]
          selected = impl.filter_options(data[key.to_s])

          # Expand file paths relative to the Boltdir
          to_expand = %w[private-key cacert token-file] & selected.keys
          to_expand.each do |opt|
            selected[opt] = File.expand_path(selected[opt], boltdir) if selected[opt].is_a?(String)
          end

          existing[key] = Bolt::Util.deep_merge(existing[key], selected)
        end
        if existing[key]['interpreters']
          existing[key]['interpreters'] = normalize_interpreters(existing[key]['interpreters'])
        end
      end
    end

    def self.normalize_interpreters(interpreters)
      Bolt::Util.walk_keys(interpreters) do |key|
        key.chars[0] == '.' ? key : '.' + key
      end
    end

    def transport_conf
      { transport: @transport,
        transports: @transports }
    end

    def default_inventoryfile
      @boltdir.inventory_file
    end

    def rerunfile
      @boltdir.rerunfile
    end

    def hiera_config
      @hiera_config || @boltdir.hiera_config
    end

    def puppetfile
      @puppetfile || @boltdir.puppetfile
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

      compile_limit = 2 * Etc.nprocessors
      unless @compile_concurrency < compile_limit
        raise Bolt::ValidationError, "Compilation is CPU-intensive, set concurrency less than #{compile_limit}"
      end

      unless %w[human json].include? @format
        raise Bolt::ValidationError, "Unsupported format: '#{@format}'"
      end

      Bolt::Util.validate_file('hiera-config', @hiera_config) if @hiera_config
      Bolt::Util.validate_file('trusted-external-command', @trusted_external) if @trusted_external

      unless @transport.nil? || Bolt::TRANSPORTS.include?(@transport.to_sym)
        raise UnknownTransportError, @transport
      end

      TRANSPORTS.each do |transport, impl|
        impl.validate(@transports[transport])
      end
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

    def casefold(path)
      path.chars.map do |l|
        l =~ /[A-Za-z]/ ? "[#{l.upcase}#{l.downcase}]" : l
      end.join
    end
  end
end
