# frozen_string_literal: true

require 'bolt/error'
require 'bolt/util'

module Bolt
  class Config
    class Transport
      attr_reader :config

      def initialize(data = {}, boltdir = nil)
        assert_hash(data)
        @config = Bolt::Util.deep_merge(defaults, filter(data))
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

      def config=(data)
        assert_hash(data)
        @config = data
        validate
      end

      def merge(*data)
        merge_data = {}

        data.compact.each do |d|
          assert_hash(d)
          merge_data = Bolt::Util.deep_merge(merge_data, d)
        end

        merged = Bolt::Util.deep_merge(@config, merge_data)
        self.class.new(merged, @boltdir)
      end

      def self.options
        unless defined? self::OPTIONS
          raise NotImplementedError,
                "Constant OPTIONS must be implemented by the transport config class"
        end
        self::OPTIONS.keys
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

      private def assert_hash(data)
        return if data.is_a?(Hash)
        raise Bolt::ValidationError,
              "Transport config must be a Hash, received #{data.class} #{data.inspect}"
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

      # Generic type validation for config options
      private def validate_type(type, *opts)
        opts.each do |opt|
          next if config[opt].nil?

          value = config[opt]
          unless value.is_a?(type) || reference?(value)
            raise Bolt::ValidationError,
                  "#{opt} must be a #{type}, received #{value.class} #{value.inspect}"
          end
        end
      end

      # Boolean type validation for config options
      # Ruby doesn't have a Boolean class, so these need to be handled separately
      # from the generic type validation
      private def assert_boolean(*opts)
        opts.each do |opt|
          next if config[opt].nil?

          value = config[opt]
          unless !!value == value || reference?(value)
            raise Bolt::ValidationError,
                  "#{opt} must be a Boolean true or false, received #{value.class} #{value.inspect}"
          end
        end
      end

      # Default validation? No validation!
      private def validate; end

      private def assert_type
        @config.each_pair do |opt, val|
          next unless (type = self.class::OPTIONS.dig(opt, :type))

          unless val.nil? || val.is_a?(type) || reference?(val)
            raise Bolt::ValidationError,
                  "#{opt} must be a #{type}, received #{val.class} #{val.inspect}"
          end
        end
      end
    end
  end
end
