# frozen_string_literal: true

require_relative '../../bolt/error'
require_relative '../../bolt/module_installer/puppetfile'
require_relative '../../bolt/module_installer/specs'

module Bolt
  class ModuleInstaller
    class Resolver
      # Resolves module specs and returns a Puppetfile object.
      #
      def resolve(specs, config = {})
        require 'puppetfile-resolver'

        # Build the document model from the specs.
        document   = PuppetfileResolver::Puppetfile::Document.new('')
        unresolved = []

        specs.specs.each do |spec|
          if spec.resolve
            document.add_module(spec.to_resolver_module)
          else
            unresolved << spec
          end
        end

        # Make sure the document model is valid.
        unless document.valid?
          message = <<~MESSAGE.chomp
            Unable to resolve module specifications:

            #{document.validation_errors.map(&:message).join("\n")}
          MESSAGE

          raise Bolt::Error.new(message, 'bolt/module-resolver-error')
        end

        # Create the resolver using the Puppetfile model. nil disables Puppet
        # version restrictions.
        resolver = PuppetfileResolver::Resolver.new(document, nil)

        # Configure and resolve the dependency graph, catching any errors
        # raised by puppetfile-resolver and re-raising them as Bolt errors.
        begin
          result = resolver.resolve(
            cache:                       nil,
            ui:                          nil,
            allow_missing_modules:       false,
            spec_searcher_configuration: spec_searcher_config(config)
          )
        rescue StandardError => e
          raise Bolt::Error.new("Unable to resolve modules: #{e.message}", 'bolt/module-resolver-error')
        end

        # Create the Puppetfile object.
        generate_puppetfile(specs, result.specifications.values, unresolved)
      end

      # Creates a puppetfile-resolver config object.
      #
      private def spec_searcher_config(config)
        PuppetfileResolver::SpecSearchers::Configuration.new.tap do |obj|
          obj.forge.proxy     = config.dig('forge', 'proxy') || config.dig('proxy')
          obj.git.proxy       = config.dig('proxy')
          obj.forge.forge_api = config.dig('forge', 'baseurl')
        end
      end

      # Creates a Puppetfile object with Module objects created from resolved and
      # unresolved specs.
      #
      private def generate_puppetfile(specs, resolved, unresolved)
        modules = []

        # Convert the resolved specs into Bolt module objects.
        resolved.each do |mod|
          # Skip over anything that isn't a module spec, such as a Puppet spec.
          next unless mod.is_a? PuppetfileResolver::Models::ModuleSpecification

          case mod.origin
          when :forge
            modules << Bolt::ModuleInstaller::Puppetfile::ForgeModule.new(
              "#{mod.owner}/#{mod.name}",
              mod.version.to_s
            )
          when :git
            spec = specs.specs.find { |s| s.name == mod.name }
            modules << Bolt::ModuleInstaller::Puppetfile::GitModule.new(
              spec.name,
              spec.git,
              spec.sha
            )
          end
        end

        # Error if there are any name conflicts between unresolved specs and
        # resolved modules. r10k will error if a Puppetfile includes duplicate
        # names, but we error early here to provide a more helpful message.
        if (name_conflicts = modules.map(&:name) & unresolved.map(&:name)).any?
          raise Bolt::Error.new(
            "Detected unresolved module specifications with the same name as a resolved module "\
            "dependency: #{name_conflicts.join(', ')}. Either remove the unresolved module specification "\
            "or set the module with the conflicting dependency to not resolve.",
            "bolt/module-name-conflict-error"
          )
        end

        # Convert the unresolved specs into Bolt module objects.
        unresolved.each do |spec|
          case spec.type
          when :forge
            modules << Bolt::ModuleInstaller::Puppetfile::ForgeModule.new(
              spec.full_name,
              spec.version_requirement
            )
          when :git
            modules << Bolt::ModuleInstaller::Puppetfile::GitModule.new(
              spec.name,
              spec.git,
              spec.ref
            )
          end
        end

        Bolt::ModuleInstaller::Puppetfile.new(modules)
      end
    end
  end
end
