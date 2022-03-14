# frozen_string_literal: true

module Bolt
  class Plugin
    class Task
      def hooks
        hook_descriptions.keys
      end

      def hook_descriptions
        {
          puppet_library: 'Run a task to install the Puppet agent package.',
          resolve_reference: 'Run a task as a plugin.',
          validate_resolve_reference: nil
        }
      end

      def name
        'task'
      end

      attr_accessor :pal, :executor, :inventory

      def initialize(context:, **_opts)
        @context = context
      end

      def run_task(opts)
        params = opts['parameters'] || {}
        options = { catch_errors: true }

        raise Bolt::ValidationError, "Task plugin requires that the 'task' is specified" unless opts['task']
        task = @context.get_validated_task(opts['task'], params)

        result = @context.run_local_task(task, params, options).first

        raise Bolt::Error.new(result.error_hash['msg'], result.error_hash['kind']) if result.error_hash
        result
      end

      def validate_options(opts)
        raise Bolt::ValidationError, "Task plugin requires that the 'task' is specified" unless opts['task']
        @context.get_validated_task(opts['task'], opts['parameters'] || {})
      end
      alias validate_resolve_reference validate_options

      def resolve_reference(opts)
        result = run_task(opts)

        unless result.value.include?('value')
          raise Bolt::ValidationError, "Task result did not return 'value': #{result.value}"
        end

        result['value']
      end

      def puppet_library(opts, target, apply_prep)
        params = opts['parameters'] || {}
        run_opts = {}
        run_opts[:run_as] = opts['_run_as'] if opts['_run_as']
        begin
          task = @context.get_validated_task(opts['task'], params)
        rescue Bolt::Error => e
          raise Bolt::Plugin::PluginError::ExecutionError.new(e.message, name, 'puppet_library')
        end
        proc do
          apply_prep.run_task([target], task, params, run_opts).first
        end
      end
    end
  end
end
