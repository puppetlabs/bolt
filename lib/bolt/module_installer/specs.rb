# frozen_string_literal: true

require 'bolt/error'
require 'bolt/module_installer/specs/forge_spec'
require 'bolt/module_installer/specs/git_spec'

module Bolt
  class ModuleInstaller
    class Specs
      def initialize(specs = [])
        @specs = []
        add_specs(specs)
        assert_unique_names
      end

      # Creates a list of specs from the modules in a Puppetfile object.
      #
      def self.from_puppetfile(puppetfile)
        new(puppetfile.modules.map(&:to_hash))
      end

      # Returns a list of specs.
      #
      def specs
        @specs.uniq(&:name)
      end

      # Returns true if the specs includes the given name.
      #
      def include?(name)
        _owner, name = name.tr('-', '/').split('/', 2)
        @specs.any? { |spec| spec.name == name }
      end

      # Adds a spec.
      #
      def add_specs(*specs)
        specs.flatten.map do |spec|
          case spec
          when Hash
            @specs.unshift spec_from_hash(spec)
          else
            @specs.unshift spec
          end
        end
      end

      # Parses a spec hash into a spec object.
      #
      private def spec_from_hash(hash)
        return ForgeSpec.new(hash) if ForgeSpec.implements?(hash)
        return GitSpec.new(hash)   if GitSpec.implements?(hash)

        raise Bolt::ValidationError, <<~MESSAGE.chomp
          Invalid module specification:
          #{hash.to_yaml.lines.drop(1).join.chomp}

          To read more about specifying modules, see https://pup.pt/bolt-module-specs
        MESSAGE
      end

      # Returns true if all specs are satisfied by the modules in a Puppetfile.
      #
      def satisfied_by?(puppetfile)
        @specs.all? do |spec|
          puppetfile.modules.any? do |mod|
            spec.satisfied_by?(mod)
          end
        end
      end

      # Asserts that all specs are unique by name. The puppetfile-resolver
      # library also does this, but the error it raises isn't as helpful.
      #
      private def assert_unique_names
        duplicates = @specs.group_by(&:name).select { |_name, specs| specs.count > 1 }

        if duplicates.any?
          message = String.new

          duplicates.each do |name, duplicate_specs|
            message << <<~MESSAGE
              Detected multiple module specifications with name #{name}:
              #{duplicate_specs.map(&:to_hash).to_yaml.lines.drop(1).join}
            MESSAGE
          end

          raise Bolt::Error.new(message.chomp, "bolt/duplicate-spec-name-error")
        end
      end
    end
  end
end
