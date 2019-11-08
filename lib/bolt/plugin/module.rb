# frozen_string_literal: true

require 'bolt/task/run'

module Bolt
  class Plugin
    class Module
      class InvalidPluginData < Bolt::Plugin::PluginError
        def initialize(plugin, msg)
          msg = "Invalid Plugin Data for #{plugin}: #{msg}"
          super(msg, 'bolt/invalid-plugin-data')
        end
      end

      def self.load(name, modules, opts)
        mod = modules[name]
        if mod&.plugin?
          opts[:mod] = mod
          plugin = Bolt::Plugin::Module.new(opts)
          plugin.setup
          plugin
        else
          raise PluginError::Unknown, name
        end
      end

      attr_reader :config

      def initialize(mod:, context:, config:, **_opts)
        @module = mod
        @config = config
        @context = context
      end

      # This method interacts with the module on disk so it's separate from initialize
      def setup
        @data = load_data
        @hook_map = find_hooks(@data['hooks'] || {})
        # If there is a config section in bolt_plugin.json, validate against that and send
        # validated values nested under `_config` key. Otherwise validate againsts the intersection
        # of all task schemas.
        # TODO: remove @send_config when deprecated
        schema = if @data['config']
                   @send_config = true
                   @data['config']
                 else
                   extract_task_parameter_schema
                 end
        @config_schema = process_schema(schema)

        validate_config(@config, @config_schema)
      end

      def name
        @module.name
      end

      def hooks
        (@hook_map.keys + [:validate_resolve_reference]).uniq
      end

      def config?
        @data.include?('config') && !@data['config'].empty?
      end

      def load_data
        JSON.parse(File.read(@module.plugin_data_file))
      rescue JSON::ParserError => e
        raise InvalidPluginData.new(e.message, name)
      end

      def process_schema(schema)
        raise InvalidPluginData.new('config specification is not an object', name) unless schema.is_a?(Hash)
        schema.each do |key, val|
          unless key =~ /\A[a-z][a-z0-9_]*\z/
            raise InvalidPluginData.new("config specification key, '#{key}',  is not allowed", name)
          end

          unless val.is_a?(Hash) && (val['type'] || '').is_a?(String)
            raise InvalidPluginData.new("config specification #{val.to_json} is not allowed", name)
          end

          type_string = val['type'] || 'Any'
          begin
            val['pcore_type'] = Puppet::Pops::Types::TypeParser.singleton.parse(type_string)
            if val['pcore_type'].is_a? Puppet::Pops::Types::PTypeReferenceType
              raise InvalidPluginData.new("Could not find type '#{type_string}' for #{key}", name)
            end
          rescue Puppet::ParseError
            raise InvalidPluginData.new("Could not parse type '#{type_string}' for #{key}", name)
          end
        end

        schema
      end

      def validate_config(config, config_schema)
        config.keys.each do |key|
          msg = "Config for #{name} plugin contains unexpected key #{key}"
          raise Bolt::ValidationError, msg unless config_schema.include?(key)
        end

        config_schema.each do |key, spec|
          val = config[key]

          unless spec['pcore_type'].instance?(val)
            raise Bolt::ValidationError, "#{name} plugin expects a #{spec['type']} for key #{key}, got: #{val}"
          end
          val.nil?
        end
        nil
      end

      def find_hooks(hook_data)
        raise InvalidPluginData.new("'hooks' must be a hash", name) unless hook_data.is_a?(Hash)

        hooks = {}
        # Load hooks specified in the config
        hook_data.each do |hook_name, hook_spec|
          unless hook_spec.is_a?(Hash) && hook_spec['task'].is_a?(String)
            msg = "Unexpected hook specification #{hook_spec.to_json} in #{@name} for hook #{hook_name}"
            raise InvalidPluginData.new(msg, name)
          end

          begin
            task = @context.get_validated_task(hook_spec['task'])
          rescue Bolt::Error => e
            msg = if e.kind == 'bolt/unknown-task'
                    "Plugin #{name} specified an unkown task '#{hook_spec['task']}' for a hook"
                  else
                    "Plugin #{name} could not load task '#{hook_spec['task']}': #{e.message}"
                  end
            raise InvalidPluginData.new(msg, name)
          end

          hooks[hook_name.to_sym] = { 'task' => task }
        end

        # Check for tasks for any hooks not already defined
        (Set.new(KNOWN_HOOKS.map) - hooks.keys).each do |hook_name|
          task_name = "#{name}::#{hook_name}"
          begin
            task = @context.get_validated_task(task_name)
          rescue Bolt::Error => e
            raise e unless e.kind == 'bolt/unknown-task'
          end
          hooks[hook_name] = { 'task' => task } if task
        end

        Bolt::Util.symbolize_top_level_keys(hooks)
      end

      def validate_params(task, params)
        @context.validate_params(task.name, params)
      end

      def process_params(task, opts)
        # opts are passed directly from inventory but all of the _ options are
        # handled previously. That may not always be the case so filter them
        # out now.
        meta, params = opts.partition { |key, _val| key.start_with?('_') }.map(&:to_h)

        # Send config with `_config` when config is defined in bolt_plugin.json
        # Otherwise, merge config with params
        # TODO: remove @send_config when deprecated
        if @send_config
          validate_params(task, params)
          params['_config'] = config if config?
        else
          params = @config ? config.merge(params) : params
          validate_params(task, params)
        end
        params['_boltdir'] = @context.boltdir.to_s

        [params, meta]
      end

      def extract_task_parameter_schema
        # Get the intersection of expected types (using Set)
        type_set = @hook_map.each_with_object({}) do |(_hook, task), acc|
          next unless (schema = task['task'].metadata['parameters'])
          schema.each do |param, scheme|
            next unless scheme['type'].is_a?(String)
            scheme['type'] = Set.new([scheme['type']])
            if acc.dig(param, 'type').is_a?(Set)
              scheme['type'].merge(acc[param]['type'])
            end
          end
          acc.merge!(schema)
        end
        # Convert Set to string
        type_set.each do |_param, schema|
          next unless schema['type']
          schema['type'] = if schema['type'].size > 1
                             "Optional[Variant[#{schema['type'].to_a.join(', ')}]]"
                           else
                             "Optional[#{schema['type'].to_a.first}]"
                           end
        end
      end

      def run_task(task, opts)
        opts = opts.reject { |key, _val| key.start_with?('_') }
        params, metaparams = process_params(task, opts)
        params = params.merge(metaparams)

        # There are no executor options to pass now.
        options = { catch_errors: true }

        result = @context.run_local_task(task,
                                         params,
                                         options).first

        raise Bolt::Error.new(result.error_hash['msg'], result.error_hash['kind']) unless result.ok
        result.value
      end

      def run_hook(hook_name, opts, value = true)
        hook = @hook_map[hook_name]
        # This shouldn't happen if the Plugin api is used
        raise PluginError::UnsupportedHook.new(name, hook_name) unless hook
        result = run_task(hook['task'], opts)

        if value
          unless result.include?('value')
            msg = "Plugin #{name} result did not include a value, got #{result}"
            raise Bolt::Plugin::PluginError::ExecutionError.new(msg, name, hook_name)
          end

          result['value']
        end
      end

      def validate_resolve_reference(opts)
        # Send config with `_config` when config is defined in bolt_plugin.json
        # Otherwise, merge config with params
        # TODO: remove @send_config when deprecated
        if @send_config
          params = opts.reject { |k, _v| k.start_with?('_') }
        else
          merged = @config.merge(opts)
          params = merged.reject { |k, _v| k.start_with?('_') }
        end
        sig = @hook_map[:resolve_reference]['task']
        if sig
          validate_params(sig, params)
        end

        if @hook_map.include?(:validate_resolve_reference)
          run_hook(:validate_resolve_reference, opts, false)
        end
      end

      # These are all the same but are defined explicitly for clarity
      def resolve_reference(opts)
        run_hook(__method__, opts)
      end

      def secret_encrypt(opts)
        run_hook(__method__, opts)
      end

      def secret_decrypt(opts)
        run_hook(__method__, opts)
      end

      def secret_createkeys(opts = {})
        run_hook(__method__, opts)
      end

      def puppet_library(opts, target, apply_prep)
        task = @hook_map[:puppet_library]['task']

        params, meta_params = process_params(task, opts)

        options = {}
        options[:run_as] = meta_params['_run_as'] if meta_params['_run_as']

        proc do
          apply_prep.run_task([target], task, params, options).first
        end
      end
    end
  end
end
