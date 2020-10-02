# frozen_string_literal: true

require 'bolt/error'
require 'bolt/module_installer/puppetfile'
require 'bolt/module_installer/specs'

module Bolt
  class ModuleInstaller
    class Resolver
      # Resolves module specs and returns a Puppetfile object.
      #
      def resolve(specs)
        require 'puppetfile-resolver'

        # Build the document model from the specs.
        document = PuppetfileResolver::Puppetfile::Document.new('')

        specs.specs.each do |spec|
          document.add_module(spec.to_resolver_module)
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
            cache:                 nil,
            ui:                    nil,
            module_paths:          [],
            allow_missing_modules: false
          )
        rescue StandardError => e
          raise Bolt::Error.new(e.message, 'bolt/module-resolver-error')
        end

        # Convert the specs returned from the resolver into Bolt module objects.
        modules = result.specifications.values.each_with_object([]) do |mod, acc|
          # Skip over anything that isn't a module spec, such as a Puppet spec.
          next unless mod.is_a? PuppetfileResolver::Models::ModuleSpecification

          case mod.origin
          when :forge
            acc << Bolt::ModuleInstaller::Puppetfile::ForgeModule.new(
              "#{mod.owner}/#{mod.name}",
              mod.version.to_s
            )
          when :git
            spec = specs.specs.find { |s| s.name == mod.name }
            acc << Bolt::ModuleInstaller::Puppetfile::GitModule.new(
              spec.name,
              spec.git,
              spec.sha
            )
          end
        end

        # Create the Puppetfile object.
        Bolt::ModuleInstaller::Puppetfile.new(modules)
      end
    end
  end
end
