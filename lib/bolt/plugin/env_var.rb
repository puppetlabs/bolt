# frozen_string_literal: true

require 'json'
module Bolt
  class Plugin
    class EnvVar
      class InvalidPluginData < Bolt::Plugin::PluginError
        def initialize(msg, plugin)
          msg = "Invalid Plugin Data for #{plugin}: #{msg}"
          super(msg, 'bolt/invalid-plugin-data')
        end
      end

      def initialize(*_args); end

      def name
        'env_var'
      end

      def hooks
        hook_descriptions.keys
      end

      def hook_descriptions
        {
          resolve_reference: 'Read values stored in environment variables.',
          validate_resolve_reference: nil
        }
      end

      def validate_resolve_reference(opts)
        unless opts['var']
          raise Bolt::ValidationError, "env_var plugin requires that the 'var' is specified"
        end
        return if opts['optional'] || opts['default']
        unless ENV[opts['var']]
          raise Bolt::ValidationError, "env_var plugin requires that the var '#{opts['var']}' be set"
        end
      end

      def resolve_reference(opts)
        reference = ENV.fetch(opts['var'], nil)
        if opts['json'] && reference
          begin
            reference = JSON.parse(reference)
          rescue JSON::ParserError => e
            raise InvalidPluginData.new(e.message, name)
          end
        end
        reference || opts['default']
      end
    end
  end
end
