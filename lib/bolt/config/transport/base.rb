# frozen_string_literal: true

require 'bolt/error'
require 'bolt/util'
require 'bolt/validator'
require 'bolt/config/transport/options'

module Bolt
  class Config
    module Transport
      class Base
        include Bolt::Config::Transport::Options

        attr_reader :input

        def initialize(data = {}, project = nil)
          assert_hash_or_config(data)
          @input    = data
          @resolved = !Bolt::Util.references?(input)
          @config   = resolved? ? Bolt::Util.deep_merge(defaults, filter(input)) : defaults
          @project  = project

          validate if resolved?
        end

        # Accessor methods
        # These are mostly all wrappers for same-named Hash methods, but they all
        # require that the config options be fully-resolved before accessing data
        def [](key)
          resolved_config[key]
        end

        def to_h
          resolved_config
        end

        def fetch(*args)
          resolved_config.fetch(*args)
        end

        def include?(args)
          resolved_config.include?(args)
        end

        def dig(*keys)
          resolved_config.dig(*keys)
        end

        private def resolved_config
          unless resolved?
            raise Bolt::Error.new(
              "Unable to access transport config, #{self.class} has unresolved config: #{input.inspect}",
              'bolt/unresolved-transport-config'
            )
          end

          @config
        end

        # Merges the original input data with the provided data, which is either a hash
        # or transport config object. Accepts multiple inputs.
        def merge(*data)
          merged = data.compact.inject(@input) do |acc, layer|
            assert_hash_or_config(layer)
            layer_data = layer.is_a?(self.class) ? layer.input : layer
            Bolt::Util.deep_merge(acc, layer_data)
          end

          self.class.new(merged, @project)
        end

        # Resolve any references in the input data, then remerge it with the defaults
        # and validate all values
        def resolve(plugins)
          @input    = plugins.resolve_references(input)
          @config   = Bolt::Util.deep_merge(defaults, filter(input))
          @resolved = true

          validate
        end

        def resolved?
          @resolved
        end

        def self.options
          unless defined? self::OPTIONS
            raise NotImplementedError,
                  "Constant OPTIONS must be implemented by the transport config class"
          end
          self::OPTIONS
        end

        def self.schema
          {
            type:       Hash,
            properties: self::TRANSPORT_OPTIONS.slice(*self::OPTIONS),
            _plugin:    true
          }
        end

        private def defaults
          unless defined? self.class::DEFAULTS
            raise NotImplementedError,
                  "Constant DEFAULTS must be implemented by the transport config class"
          end
          self.class::DEFAULTS
        end

        private def filter(unfiltered)
          unfiltered.slice(*self.class.options)
        end

        private def assert_hash_or_config(data)
          return if data.is_a?(Hash) || data.is_a?(self.class)
          raise Bolt::ValidationError,
                "Transport config must be a Hash or #{self.class}, received #{data.class} #{data.inspect}"
        end

        private def normalize_interpreters(interpreters)
          Bolt::Util.walk_keys(interpreters) do |key|
            key.chars[0] == '.' ? key : '.' + key
          end
        end

        # Validation defaults to just asserting the option types
        private def validate
          Bolt::Validator.new.validate(@config.compact, self.class.schema)
        end
      end
    end
  end
end
