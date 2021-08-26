# frozen_string_literal: true

require 'bolt/inventory'
require 'bolt/executor'
require 'bolt/module'
require 'bolt/pal'
require 'bolt/plugin/cache'
require 'bolt/plugin/puppetdb'

module Bolt
  class Plugin
    KNOWN_HOOKS = %i[
      puppet_library
      resolve_reference
      secret_encrypt
      secret_decrypt
      secret_createkeys
      validate_resolve_reference
    ].freeze

    class PluginError < Bolt::Error
      class ExecutionError < PluginError
        def initialize(msg, plugin_name, location)
          mess = "Error executing plugin #{plugin_name} from #{location}: #{msg}"
          super(mess, 'bolt/plugin-error')
        end
      end

      class Unknown < PluginError
        def initialize(plugin_name)
          super("Unknown plugin: '#{plugin_name}'", 'bolt/unknown-plugin')
        end
      end

      class UnsupportedHook < PluginError
        def initialize(plugin_name, hook)
          super("Plugin #{plugin_name} does not support #{hook}", 'bolt/unsupported-hook')
        end
      end

      class LoadingDisabled < PluginError
        def initialize(plugin_name)
          msg = "Cannot load plugin #{plugin_name}: plugin loading is disabled"
          super(msg, 'bolt/plugin-loading-disabled', { 'plugin_name' => plugin_name })
        end
      end
    end

    class PluginContext
      def initialize(config, pal, plugins)
        @pal = pal
        @config = config
        @plugins = plugins
      end

      def serial_executor
        @serial_executor ||= Bolt::Executor.new(1)
      end
      private :serial_executor

      def empty_inventory
        @empty_inventory ||= Bolt::Inventory.empty
      end
      private :empty_inventory

      def with_a_compiler
        # If we're already inside a pal compiler block use that compiler
        # This may blow up if you try to load a task in catalog pal. Should we
        # guard against that?
        compiler = nil
        if defined?(Puppet)
          begin
            compiler = Puppet.lookup(:pal_compiler)
          rescue Puppet::Context::UndefinedBindingError; end # rubocop:disable Lint/SuppressedException
        end

        if compiler
          yield compiler
        else
          @pal.in_bolt_compiler do |temp_compiler|
            yield temp_compiler
          end
        end
      end
      private :with_a_compiler

      def get_validated_task(task_name, params = nil)
        with_a_compiler do |compiler|
          tasksig = compiler.task_signature(task_name)

          raise Bolt::Error.unknown_task(task_name) unless tasksig

          Bolt::Task::Run.validate_params(tasksig, params) if params
          Bolt::Task.from_task_signature(tasksig)
        end
      end

      def validate_params(task_name, params)
        with_a_compiler do |compiler|
          tasksig = compiler.task_signature(task_name)

          raise Bolt::Error.new("#{task_name} could not be found", 'bolt/plugin-error') unless tasksig

          Bolt::Task::Run.validate_params(tasksig, params)
        end
        nil
      end

      # By passing `_` keys in params the caller can send metaparams directly to the task
      # _catch_errors must be passed as an executor option not a param
      def run_local_task(task, params, options)
        # Make sure we're in a compiler to use the sensitive type
        with_a_compiler do |_comp|
          params = Bolt::Task::Run.wrap_sensitive(task, params)
          Bolt::Task::Run.run_task(
            task,
            empty_inventory.get_targets('localhost'),
            params,
            options,
            serial_executor
          )
        end
      end

      def boltdir
        @config.project.path
      end
    end

    RUBY_PLUGINS = %w[task prompt env_var puppetdb puppet_connect_data].freeze
    BUILTIN_PLUGINS = %w[task terraform pkcs7 prompt vault aws_inventory puppetdb azure_inventory
                         yaml env_var gcloud_inventory].freeze
    DEFAULT_PLUGIN_HOOKS = { 'puppet_library' => { 'plugin' => 'puppet_agent', 'stop_service' => true } }.freeze

    attr_reader :pal, :plugin_context
    attr_writer :plugin_hooks

    def initialize(config, pal, analytics = Bolt::Analytics::NoopClient.new, load_plugins: true)
      @config = config
      @analytics = analytics
      @plugin_context = PluginContext.new(config, pal, self)
      @plugins = {}
      @pal = pal
      @load_plugins = load_plugins
      @unknown = Set.new
      @resolution_stack = []
      @unresolved_plugin_configs = config.plugins.dup
      # The puppetdb plugin config comes from the puppetdb section, not from
      # the plugins section
      if @unresolved_plugin_configs.key?('puppetdb')
        msg = "Configuration for the PuppetDB plugin must be in the 'puppetdb' config section, not 'plugins'"
        raise Bolt::Error.new(msg, 'bolt/plugin-error')
      end
      @unresolved_plugin_configs['puppetdb'] = config.puppetdb if config.puppetdb
    end

    # Returns a map of configured plugin hooks. Any unresolved plugin references
    # are resolved.
    #
    # @return [Hash[String, Hash]]
    #
    def plugin_hooks
      @plugin_hooks ||= DEFAULT_PLUGIN_HOOKS.merge(resolve_references(@config.plugin_hooks))
    end

    def modules
      @modules ||= Bolt::Module.discover(@pal.full_modulepath, @config.project)
    end

    def add_plugin(plugin)
      @plugins[plugin.name] = plugin
    end

    def add_ruby_plugin(plugin_name)
      cls_name = Bolt::Util.snake_name_to_class_name(plugin_name)
      filename = "bolt/plugin/#{plugin_name}"
      require filename
      cls = Kernel.const_get("Bolt::Plugin::#{cls_name}")
      opts = {
        context: @plugin_context,
        config: config_for_plugin(plugin_name)
      }

      plugin = cls.new(**opts)
      add_plugin(plugin)
    end

    def add_module_plugin(plugin_name)
      opts = {
        context: @plugin_context,
        # Make sure that the plugin's config is validated _before_ the unknown-plugin
        # and loading-disabled checks. This way, we can fail early on invalid plugin
        # config instead of _after_ loading the modulepath (which can be expensive).
        config: config_for_plugin(plugin_name)
      }

      mod = modules[plugin_name]

      plugin = Bolt::Plugin::Module.load(mod, opts)
      add_plugin(plugin)
    end

    def config_for_plugin(plugin_name)
      return {} unless @unresolved_plugin_configs.include?(plugin_name)
      if @resolution_stack.include?(plugin_name)
        msg = "Configuration for plugin '#{plugin_name}' depends on the plugin itself"
        raise PluginError.new(msg, 'bolt/plugin-error')
      else
        @resolution_stack.push(plugin_name)
        config = resolve_references(@unresolved_plugin_configs[plugin_name])
        @unresolved_plugin_configs.delete(plugin_name)
        @resolution_stack.pop
        config
      end
    end

    def known_plugin?(plugin_name)
      @plugins.include?(plugin_name) ||
        RUBY_PLUGINS.include?(plugin_name) ||
        (modules.include?(plugin_name) && modules[plugin_name].plugin?)
    end

    def get_hook(plugin_name, hook)
      plugin = by_name(plugin_name)
      raise PluginError::Unknown, plugin_name unless plugin
      raise PluginError::UnsupportedHook.new(plugin_name, hook) unless plugin.hooks.include?(hook)
      @analytics.report_bundled_content("Plugin #{hook}", plugin_name)

      plugin.method(hook)
    end

    # Calling by_name or get_hook will load any module based plugin automatically
    def by_name(plugin_name)
      if known_plugin?(plugin_name)
        if @plugins.include?(plugin_name)
          @plugins[plugin_name]
        elsif !@load_plugins
          raise PluginError::LoadingDisabled, plugin_name
        elsif RUBY_PLUGINS.include?(plugin_name)
          add_ruby_plugin(plugin_name)
        else
          add_module_plugin(plugin_name)
        end
      end
    end

    # Loads all plugins and returns a map of plugin names to hooks.
    #
    def list_plugins
      load_all_plugins

      hooks = KNOWN_HOOKS.map { |hook| [hook, {}] }.to_h

      @plugins.sort.each do |name, plugin|
        # Don't show the Puppet Connect plugin for now.
        next if name == 'puppet_connect_data'

        case plugin
        when Bolt::Plugin::Module
          plugin.hook_map.each do |hook, spec|
            next unless hooks.include?(hook)
            hooks[hook][name] = spec['task'].description
          end
        else
          plugin.hook_descriptions.each do |hook, description|
            hooks[hook][name] = description
          end
        end
      end

      hooks
    end

    # Loads all plugins available to the project.
    #
    private def load_all_plugins
      modules.each do |name, mod|
        next unless mod.plugin?
        by_name(name)
      end

      RUBY_PLUGINS.each { |name| by_name(name) }
    end

    def puppetdb_client
      by_name('puppetdb').puppetdb_client
    end

    # Evaluate all _plugin references in a data structure. Leaves are
    # evaluated and then their parents are evaluated with references replaced
    # by their values. If the result of a reference contains more references,
    # they are resolved again before continuing to ascend the tree. The final
    # result will not contain any references.
    def resolve_references(data)
      Bolt::Util.postwalk_vals(data) do |value|
        reference?(value) ? resolve_references(resolve_single_reference(value)) : value
      end
    rescue SystemStackError
      raise Bolt::Error.new("Stack depth exceeded while recursively resolving references.",
                            "bolt/recursive-reference-loop")
    end

    # Iteratively resolves "top-level" references until the result no longer
    # has top-level references. A top-level reference is one which is not
    # contained within another hash. It may be either the actual top-level
    # result or arbitrarily nested within arrays. If parameters of the
    # reference are themselves references, they will be looked. Any remaining
    # references nested inside the result will *not* be evaluated once the
    # top-level result is not a reference.  This is used to resolve the
    # `targets` and `groups` keys which are allowed to be references or
    # arrays of references, but which may return data with nested references
    # that should be resolved lazily. The end result will either be a single
    # hash or a flat array of hashes.
    def resolve_top_level_references(data)
      if data.is_a?(Array)
        data.flat_map { |elem| resolve_top_level_references(elem) }
      elsif reference?(data)
        partially_resolved = data.transform_values do |v|
          resolve_references(v)
        end
        fully_resolved = resolve_single_reference(partially_resolved)
        # The top-level reference may have returned more references, so repeat the process
        resolve_top_level_references(fully_resolved)
      else
        data
      end
    end

    # Evaluates a single reference. The value returned may be another
    # reference.
    def resolve_single_reference(reference)
      plugin_cache = if cache?(reference)
                       cache = Bolt::Plugin::Cache.new(reference,
                                                       @config.project.plugin_cache_file,
                                                       @config.plugin_cache)
                       entry = cache.read_and_clean_cache
                       return entry unless entry.nil?

                       cache
                     end

      plugin_name = reference['_plugin']
      hook = get_hook(plugin_name, :resolve_reference)

      begin
        validate_proc = get_hook(plugin_name, :validate_resolve_reference)
      rescue PluginError
        validate_proc = proc { |*args| } # Nothing to do
      end

      validate_proc.call(reference)

      result = begin
        # Evaluate the plugin and then recursively evaluate any plugin returned by it.
        hook.call(reference)
      rescue StandardError => e
        loc = "resolve_reference in #{plugin_name}"
        raise PluginError::ExecutionError.new(e.message, plugin_name, loc)
      end

      plugin_cache.write_cache(result) if cache?(reference)

      result
    end
    private :resolve_single_reference

    private def cache?(reference)
      reference.key?('_cache') || @config.plugin_cache.key?('ttl')
    end

    # Checks whether a given value is a _plugin reference
    def reference?(input)
      input.is_a?(Hash) && input.key?('_plugin')
    end
  end
end

# references PluginError
require 'bolt/plugin/module'
