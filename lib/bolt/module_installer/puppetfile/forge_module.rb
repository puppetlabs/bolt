# frozen_string_literal: true

require 'semantic_puppet'
require 'bolt/module_installer/puppetfile/module'

# This class represents a resolved Forge module.
#
module Bolt
  class ModuleInstaller
    class Puppetfile
      class ForgeModule < Module
        attr_reader :version

        def initialize(name, version)
          super(name)
          @version = parse_version(version)
          @type    = :forge
        end

        # Parses the version into a Semantic Puppet version.
        #
        private def parse_version(version)
          return unless version.is_a?(String)

          unless SemanticPuppet::Version.valid?(version)
            raise Bolt::ValidationError,
                  "Invalid version for Forge module #{@full_name}: #{version.inspect}"
          end

          SemanticPuppet::Version.parse(version)
        end

        # Returns a Puppetfile module specification.
        #
        def to_spec
          if @version
            "mod '#{@full_name}', '#{@version}'"
          else
            "mod '#{@full_name}'"
          end
        end

        # Returns a hash that can be used to create a module specification.
        #
        def to_hash
          {
            'name'                => @full_name,
            'version_requirement' => @version ? @version.to_s : nil
          }.compact
        end
      end
    end
  end
end
