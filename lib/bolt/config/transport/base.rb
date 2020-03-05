# frozen_string_literal: true

require 'bolt/error'
require 'bolt/util'

module Bolt
  class Config
    module Transport
      class Base
        attr_reader :input

        def initialize(data = {}, boltdir = nil)
          assert_hash_or_config(data)
          @input   = reference?(data) ? data : filter(data)
          @config  = Bolt::Util.deep_merge(defaults, @input)
          @boltdir = boltdir
          validate
        end

        def [](key)
          @config[key]
        end

        def to_h
          @config
        end

        def fetch(*args)
          @config.fetch(*args)
        end

        def include?(args)
          @config.include?(args)
        end

        def dig(*keys)
          @config.dig(*keys)
        end

        def input=(data)
          assert_hash_or_config(data)
          @input  = data
          @config = Bolt::Util.deep_merge(defaults, @input)
          validate
        end

        # Merges the original input data with the provided data, which is either a hash
        # or transport config object. Accepts multiple inputs.
        def merge(*data)
          merged = data.compact.inject(@input) do |acc, layer|
            assert_hash_or_config(layer)
            layer_data = layer.is_a?(self.class) ? layer.input : layer
            Bolt::Util.deep_merge(acc, layer_data)
          end

          self.class.new(merged, @boltdir)
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
          unfiltered.slice(*self.class.options.keys)
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

        # Checks whether a config option contains a plugin reference, which
        # should always be a valid input
        private def reference?(value)
          value.is_a?(Hash) && value.key?('_plugin')
        end

        # Validation defaults to just asserting the option types
        private def validate
          assert_type
        end

        # Validates that each option is the correct type. Types are loaded from the OPTIONS hash.
        private def assert_type
          # It's possible for the input to be a plugin reference, so we shouldn't validate
          # any of the types here. Once the reference is resolved it will be validated.
          return if reference?(@input)

          @config.each_pair do |opt, val|
            next unless (type = self.class.options.dig(opt, :type))

            # Options that accept a Boolean value are indicated by the type TrueClass, so we
            # need some special handling here to check if the value is either true or false.
            if type == TrueClass
              unless [true, false].include?(val)
                raise Bolt::ValidationError,
                      "#{opt} must be a Boolean true or false, received #{val.class} #{val.inspect}"
              end
            else
              unless val.nil? || val.is_a?(type) || reference?(val)
                raise Bolt::ValidationError,
                      "#{opt} must be a #{type}, received #{val.class} #{val.inspect}"
              end
            end
          end
        end
      end
    end
  end
end
