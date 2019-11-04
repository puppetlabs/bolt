# frozen_string_literal: true

require 'etc'
require 'logging'
require 'pathname'
require 'bolt/boltdir'
require 'bolt/transport/ssh'
require 'bolt/transport/winrm'
require 'bolt/transport/orch'
require 'bolt/transport/local'
require 'bolt/transport/local_windows'
require 'bolt/transport/docker'
require 'bolt/transport/lxd'
require 'bolt/transport/remote'
require 'bolt/util'

module Bolt
  TRANSPORTS = {
    ssh: Bolt::Transport::SSH,
    winrm: Bolt::Transport::WinRM,
    pcp: Bolt::Transport::Orch,
    local: Bolt::Util.windows? ? Bolt::Transport::LocalWindows : Bolt::Transport::Local,
    docker: Bolt::Transport::Docker,
    lxd: Bolt::Transport::LXD,
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
                  :puppetfile_config, :plugins, :plugin_hooks, :future
    attr_writer :modulepath

    TRANSPORT_OPTIONS = %i[password run-as sudo-password extensions
                           private-key tty tmpdir user connect-timeout disconnect-timeout
                           cacert token-file service-url interpreters file-protocol smb-port realm].freeze

    PUPPETFILE_OPTIONS = %w[proxy forge].freeze

    def self.default
      new(Bolt::Boltdir.new('.'), {})
    end

    def self.from_boltdir(boltdir, overrides = {})
      data = Bolt::Util.read_config_file(nil, [boltdir.config_file], 'config') || {}
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
      @compile_concurrency = Etc.nprocessors
      @transport = 'ssh'
      @format = 'human'
      @puppetdb = {}
      @color = true
      @save_rerun = true
      @puppetfile_config = {}
      @plugins = {}
      @plugin_hooks = { 'puppet_library' => { 'plugin' => 'puppet_agent', 'stop_service' => true } }

      # add an entry for the default console logger
      @log = { 'console' => {} }

      @transports = {}

      TRANSPORTS.each do |key, transport|
        @transports[key] = transport.default_options
      end

      update_from_file(config_data)
      apply_overrides(overrides)

      validate
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

    def normalize_interpreters(interpreters)
      Bolt::Util.walk_keys(interpreters) do |key|
        key.chars[0] == '.' ? key : '.' + key
      end
    end

    def normalize_log(target)
      return target if target == 'console'
      target = target[5..-1] if target.start_with?('file:')
      if @future
        'file:' + File.expand_path(target, @boltdir.path)
      else
        'file:' + File.expand_path(target)
      end
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
      @future = data['future'] == true

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
      @compile_concurrency = data['compile-concurrency'] if data.key?('compile-concurrency')

      @save_rerun = data['save-rerun'] if data.key?('save-rerun')

      # Plugins are only settable from config not inventory so we can overwrite
      @plugins = data['plugins'] if data.key?('plugins')
      @plugin_hooks.merge!(data['plugin_hooks']) if data.key?('plugin_hooks')

      %w[concurrency format puppetdb color transport].each do |key|
        send("#{key}=", data[key]) if data.key?(key)
      end

      TRANSPORTS.each do |key, impl|
        if data[key.to_s]
          selected = impl.filter_options(data[key.to_s])
          if @future
            to_expand = %w[private-key cacert token-file] & selected.keys
            to_expand.each do |opt|
              selected[opt] = File.expand_path(selected[opt], @boltdir.path) if opt.is_a?(String)
            end
          end

          @transports[key] = Bolt::Util.deep_merge(@transports[key], selected)
        end
        if @transports[key]['interpreters']
          @transports[key]['interpreters'] = normalize_interpreters(@transports[key]['interpreters'])
        end
      end
    end
    private :update_from_file

    def apply_overrides(options)
      %i[concurrency transport format trace modulepath inventoryfile color].each do |key|
        send("#{key}=", options[key]) if options.key?(key)
      end

      @save_rerun = options[:'save-rerun'] if options.key?(:'save-rerun')

      if options[:debug]
        @log['console'][:level] = :debug
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

    def rerunfile
      @boltdir.rerunfile
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

      compile_limit = 2 * Etc.nprocessors
      unless @compile_concurrency < compile_limit
        raise Bolt::ValidationError, "Compilation is CPU-intensive, set concurrency less than #{compile_limit}"
      end

      unless %w[human json].include? @format
        raise Bolt::ValidationError, "Unsupported format: '#{@format}'"
      end

      Bolt::Util.validate_file('hiera-config', @hiera_config) if @hiera_config

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
