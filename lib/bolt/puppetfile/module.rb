# frozen_string_literal: true

require 'bolt/error'

# This class represents a module specification. It used by the Bolt::Puppetfile
# class to have a consistent API for accessing a module's attributes.
#
module Bolt
  class Puppetfile
    class Module
      attr_reader :owner, :name, :version

      def initialize(owner, name, version = nil)
        @owner   = owner
        @name    = name
        @version = version
      end

      # Creates a new module from a hash.
      #
      def self.from_hash(mod)
        unless mod['name'].is_a?(String)
          raise Bolt::ValidationError,
                "Module name must be a String, not #{mod['name'].inspect}"
        end

        owner, name = mod['name'].tr('/', '-').split('-', 2)

        unless owner && name
          raise Bolt::ValidationError, "Module name #{mod['name']} must include both the owner and module name."
        end

        new(owner, name, mod['version_requirement'])
      end

      # Returns the module's title.
      #
      def title
        "#{@owner}-#{@name}"
      end

      # Checks two modules for equality.
      #
      def eql?(other)
        self.class == other.class &&
          @owner == other.owner &&
          @name == other.name &&
          versions_intersect?(other)
      end
      alias == eql?

      # Returns true if the versions of two modules intersect. Used to determine
      # if an installed module satisfies the version requirement of another.
      #
      def versions_intersect?(other)
        range       = ::SemanticPuppet::VersionRange.parse(@version || '')
        other_range = ::SemanticPuppet::VersionRange.parse(other.version || '')

        range.intersection(other_range) != ::SemanticPuppet::VersionRange::EMPTY_RANGE
      end

      # Hashes the module.
      #
      def hash
        [@owner, @name].hash
      end

      # Returns a hash representation similar to the module
      # declaration.
      #
      def to_hash
        {
          'name'                => title,
          'version_requirement' => version
        }.compact
      end

      # Returns the Puppetfile specification for the module.
      #
      def to_spec
        if @version
          "mod #{title.inspect}, #{@version.inspect}"
        else
          "mod #{title.inspect}"
        end
      end
    end
  end
end
