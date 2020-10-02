# frozen_string_literal: true

require 'semantic_puppet'
require 'set'

require 'bolt/error'

# This class represents a Forge module specification.
#
module Bolt
  class ModuleInstaller
    class Specs
      class ForgeSpec
        NAME_REGEX    = %r{\A[a-z][a-z0-9_]*[-/](?<name>[a-z][a-z0-9_]*)\z}.freeze
        REQUIRED_KEYS = Set.new(%w[name]).freeze
        KNOWN_KEYS    = Set.new(%w[name version_requirement]).freeze

        attr_reader :full_name, :name, :semantic_version, :type

        def initialize(init_hash)
          @full_name, @name                       = parse_name(init_hash['name'])
          @version_requirement, @semantic_version = parse_version_requirement(init_hash['version_requirement'])
          @type                                   = :forge
        end

        def self.implements?(hash)
          KNOWN_KEYS.superset?(hash.keys.to_set) && REQUIRED_KEYS.subset?(hash.keys.to_set)
        end

        # Formats the full name and extracts the module name.
        #
        private def parse_name(name)
          unless (match = name.match(NAME_REGEX))
            raise Bolt::ValidationError,
                  "Invalid name for Forge module specification: #{name}. Name must match "\
                  "'owner/name', must start with a lowercase letter, and may only include "\
                  "lowercase letters, digits, and underscores."
          end

          [name.tr('-', '/'), match[:name]]
        end

        # Parses the version into a Semantic Puppet version range.
        #
        private def parse_version_requirement(version_requirement)
          [version_requirement, SemanticPuppet::VersionRange.parse(version_requirement || '>= 0')]
        rescue StandardError
          raise Bolt::ValidationError,
                "Invalid version requirement for Forge module specification #{@full_name}: "\
                "#{version_requirement.inspect}"
        end

        # Returns true if the specification is satisfied by the module.
        #
        def satisfied_by?(mod)
          @type == mod.type &&
            @full_name == mod.full_name &&
            !mod.version.nil? &&
            @semantic_version.cover?(mod.version)
        end

        # Returns a hash matching the module spec in bolt-project.yaml
        #
        def to_hash
          {
            'name'                => @full_name,
            'version_requirement' => @version_requirement
          }.compact
        end

        # Creates a PuppetfileResolver::Puppetfile::ForgeModule object, which is
        # used to generate a graph of resolved modules.
        #
        def to_resolver_module
          require 'puppetfile-resolver'

          PuppetfileResolver::Puppetfile::ForgeModule.new(@full_name).tap do |mod|
            mod.version = @version_requirement
          end
        end
      end
    end
  end
end
