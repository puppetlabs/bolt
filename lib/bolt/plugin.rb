# frozen_string_literal: true

require 'bolt/inventory'
require 'bolt/executor'
require 'bolt/module'
require 'bolt/pal'
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
        @empty_inventory ||= Bolt::Inventory::Inventory2.new({}, plugins: @plugins)
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
        @config.boltdir.path
      end
    end

    def self.setup(config, pal, pdb_client, analytics)
      plugins = new(config, pal, analytics)

      # PDB is special because it needs the PDB client. Since it has no config,
      # we can just add it first.
      plugins.add_plugin(Bolt::Plugin::Puppetdb.new(pdb_client))

      # Initialize any plugins referenced in config. This will also indirectly
      # initialize any plugins they depend on.
      if plugins.reference?(config.plugins)
        msg = "The 'plugins' setting cannot be set by a plugin reference"
        raise PluginError.new(msg, 'bolt/plugin-error')
      end

      config.plugins.keys.each do |plugin|
        plugins.by_name(plugin)
      end

      plugins.plugin_hooks.merge!(plugins.resolve_references(config.plugin_hooks))

      plugins
    end

    RUBY_PLUGINS = %w[task pkcs7 prompt].freeze
    BUILTIN_PLUGINS = %w[task terraform pkcs7 prompt vault aws_inventory puppetdb azure_inventory yaml].freeze
    DEFAULT_PLUGIN_HOOKS = { 'puppet_library' => { 'plugin' => 'puppet_agent', 'stop_service' => true } }.freeze

    attr_reader :pal, :plugin_context
    attr_accessor :plugin_hooks

    private_class_method :new

    def initialize(config, pal, analytics)
      @config = config
      @analytics = analytics
      @plugin_context = PluginContext.new(config, pal, self)
      @plugins = {}
      @pal = pal
      @unknown = Set.new
      @resolution_stack = []
      @unresolved_plugin_configs = config.plugins.dup
      @plugin_hooks = DEFAULT_PLUGIN_HOOKS.dup
    end

    def modules
      @modules ||= Bolt::Module.discover(@pal.modulepath)
    end

    # Generally this is private. Puppetdb is special though
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
        config: config_for_plugin(plugin_name)
      }

      plugin = Bolt::Plugin::Module.load(plugin_name, modules, opts)
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

    def get_hook(plugin_name, hook)
      plugin = by_name(plugin_name)
      raise PluginError::Unknown, plugin_name unless plugin
      raise PluginError::UnsupportedHook.new(plugin_name, hook) unless plugin.hooks.include?(hook)
      @analytics.report_bundled_content("Plugin #{hook}", plugin_name)

      plugin.method(hook)
    end

    # Calling by_name or get_hook will load any module based plugin automatically
    def by_name(plugin_name)
      return @plugins[plugin_name] if @plugins.include?(plugin_name)
      begin
        if RUBY_PLUGINS.include?(plugin_name)
          add_ruby_plugin(plugin_name)
        elsif !@unknown.include?(plugin_name)
          add_module_plugin(plugin_name)
        end
      rescue PluginError::Unknown
        @unknown << plugin_name
        nil
      end
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
        partially_resolved = data.map do |k, v|
          [k, resolve_references(v)]
        end.to_h
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
      plugin_name = reference['_plugin']
      hook = get_hook(plugin_name, :resolve_reference)

      begin
        validate_proc = get_hook(plugin_name, :validate_resolve_reference)
      rescue PluginError
        validate_proc = proc { |*args| }
      end

      validate_proc.call(reference)

      begin
        # Evaluate the plugin and then recursively evaluate any plugin returned by it.
        hook.call(reference)
      rescue StandardError => e
        loc = "resolve_reference in #{plugin_name}"
        raise PluginError::ExecutionError.new(e.message, plugin_name, loc)
      end
    end
    private :resolve_single_reference

    # Checks whether a given value is a _plugin reference
    def reference?(input)
      input.is_a?(Hash) && input.key?('_plugin')
    end
  end
end

# references PluginError
require 'bolt/plugin/module'
