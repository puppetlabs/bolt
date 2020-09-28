# frozen_string_literal: true

require 'bolt/error'
require 'bolt/puppetfile/module'

# This class manages the logical contents of a Puppetfile. It includes methods
# for parsing a Puppetfile and its modules, resolving module dependencies,
# and writing a Puppetfile.
#
module Bolt
  class Puppetfile
    attr_reader :modules

    def initialize(modules = [])
      @modules = Set.new
      add_modules(modules)
    end

    # Loads a Puppetfile and parses its module specifications, returning a
    # Bolt::Puppetfile object with the modules set.
    #
    def self.parse(path, skip_unsupported_modules: false)
      require 'puppetfile-resolver'
      require 'puppetfile-resolver/puppetfile/parser/r10k_eval'

      begin
        parsed = ::PuppetfileResolver::Puppetfile::Parser::R10KEval.parse(File.read(path))
      rescue StandardError => e
        raise Bolt::Error.new(
          "Unable to parse Puppetfile #{path}: #{e.message}",
          'bolt/puppetfile-parsing'
        )
      end

      unless parsed.valid?
        raise Bolt::ValidationError,
              "Unable to parse Puppetfile #{path}. This may not be a Puppetfile "\
              "managed by Bolt."
      end

      modules = parsed.modules.each_with_object([]) do |mod, acc|
        unless mod.instance_of? PuppetfileResolver::Puppetfile::ForgeModule
          next if skip_unsupported_modules

          raise Bolt::ValidationError,
                "Module '#{mod.title}' is not a Puppet Forge module. Unable to "\
                "parse Puppetfile #{path}."
        end

        acc << Bolt::Puppetfile::Module.new(mod.owner, mod.name, mod.version)
      end

      new(modules)
    end

    # Writes a Puppetfile that includes specifications for each of the
    # modules.
    #
    def write(path)
      File.open(path, 'w') do |file|
        file.puts '# This Puppetfile is managed by Bolt. Do not edit.'
        modules.each { |mod| file.puts mod.to_spec }
      end
    rescue SystemCallError => e
      raise Bolt::FileError.new(
        "#{e.message}: unable to write Puppetfile.",
        path
      )
    end

    # Resolves module dependencies using the puppetfile-resolver library. The
    # resolver will return a document model including all module dependencies
    # and the latest version that can be installed for each. The document model
    # is parsed and turned into a Set of Bolt::Puppetfile::Module objects.
    #
    def resolve
      require 'puppetfile-resolver'

      # Build the document model from the modules.
      model = PuppetfileResolver::Puppetfile::Document.new('')

      @modules.each do |mod|
        model.add_module(
          PuppetfileResolver::Puppetfile::ForgeModule.new(mod.title).tap do |tap|
            tap.version = mod.version || :latest
          end
        )
      end

      # Make sure the Puppetfile model is valid.
      unless model.valid?
        raise Bolt::ValidationError,
              "Unable to resolve dependencies for modules: #{@modules.map(&:title).join(', ')}"
      end

      # Create the resolver using the Puppetfile model. nil disables Puppet
      # version restrictions.
      resolver = PuppetfileResolver::Resolver.new(model, nil)

      # Configure and resolve the dependency graph, catching any errors
      # raised by puppetfile-resolver and re-raising them as Bolt errors.
      begin
        result = resolver.resolve(
          cache:                 nil,
          ui:                    nil,
          module_paths:          [],
          allow_missing_modules: true
        )
      rescue StandardError => e
        raise Bolt::Error.new(e.message, 'bolt/puppetfile-resolver-error')
      end

      # Validate that the modules exist.
      assert_missing_modules(result.specifications)

      # Filter the dependency graph to only include module specifications. This
      # will only remove the Puppet version specification, which is not needed.
      specs = result.specifications.select do |_name, spec|
        spec.instance_of? PuppetfileResolver::Models::ModuleSpecification
      end

      @modules = specs.map do |_name, spec|
        Bolt::Puppetfile::Module.new(spec.owner, spec.name, spec.version.to_s)
      end.to_set
    end

    # Adds to the set of modules.
    #
    def add_modules(modules)
      Array(modules).each do |mod|
        case mod
        when Bolt::Puppetfile::Module
          @modules << mod
        when Hash
          @modules << Bolt::Puppetfile::Module.from_hash(mod)
        else
          raise Bolt::ValidationError, "Module must be a Bolt::Puppetfile::Module or Hash."
        end
      end

      @modules
    end

    # Checks for any missing dependencies, raising an error if there
    # are any.
    #
    private def assert_missing_modules(specifications)
      missing_graph = specifications.select do |_name, spec|
        spec.instance_of? PuppetfileResolver::Models::MissingModuleSpecification
      end

      return if missing_graph.empty?

      # Maps the names of dependencies to their dependees. The graph only
      # provides the name for a missing module (i.e. no owner), so use the name
      # as the key. This will then map that to a hash containing the module's
      # title (i.e. with owner) and the set of dependees for the module.
      dependencies = specifications.each_with_object({}) do |(_name, spec), deps|
        next unless spec.instance_of? PuppetfileResolver::Models::ModuleSpecification

        spec.metadata(nil, nil).fetch(:dependencies, []).each do |dep|
          _, name = dep[:name].tr('/', '-').split('-', 2)

          deps[name] ||= {
            title:     dep[:name],
            dependees: Set.new
          }

          deps[name][:dependees] << "#{spec.owner}-#{spec.name}"
        end
      end

      # Make a split between missing dependencies and missing modules. The
      # former are modules that are listed in another module's dependencies,
      # while the latter are those defined by the user.
      missing_dependencies, missing_modules = missing_graph.partition do |name, _spec|
        dependencies.key?(name)
      end.map(&:to_h)

      # Build the error message.
      message = String.new("Unknown modules, unable to resolve\n\n")

      if missing_modules.any?
        message << "  Unknown modules:\n"

        missing_modules.each_key do |name|
          title = @modules.select { |mod| mod.name == name }.first.title
          message << "    #{title}\n"
        end

        message << "\n"
      end

      if missing_dependencies.any?
        message << "  Unknown module dependencies:\n"

        missing_dependencies.each_key do |mod|
          message << "    #{dependencies.dig(mod, :title)} which is a dependency of "\
                     "#{dependencies.dig(mod, :dependees).to_a.join(', ')}\n"
        end
      end

      raise Bolt::Error.new(message.chomp, 'bolt/missing-modules-error')
    end
  end
end
