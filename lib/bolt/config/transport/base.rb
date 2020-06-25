# frozen_string_literal: true

require 'bolt/error'
require 'bolt/util'
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
          assert_type
        end

        # Validates that each option is the correct type. Types are loaded from the TRANSPORT_OPTIONS hash.
        private def assert_type
          @config.each_pair do |opt, val|
            types = Array(TRANSPORT_OPTIONS.dig(opt, :type)).compact

            next if val.nil? || types.empty? || types.include?(val.class)

            # Ruby doesn't have a Boolean class, so add it to the types list if TrueClass or FalseClass
            # are present.
            if types.include?(TrueClass) || types.include?(FalseClass)
              types = types - [TrueClass, FalseClass] + ['Boolean']
            end

            raise Bolt::ValidationError,
                  "#{opt} must be of type #{types.join(', ')}; received #{val.class} #{val.inspect} "
          end
        end
      end
    end
  end
end
