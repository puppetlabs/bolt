# frozen_string_literal: true

require 'bolt/error'
require 'bolt/module_installer/puppetfile/forge_module'
require 'bolt/module_installer/puppetfile/git_module'

# This class manages the logical contents of a Puppetfile. It includes methods
# for parsing and generating a Puppetfile.
#
module Bolt
  class ModuleInstaller
    class Puppetfile
      attr_reader :modules

      def initialize(modules = [])
        @modules = modules
      end

      # Loads a Puppetfile and parses its modules.
      #
      def self.parse(path, skip_unsupported_modules: false)
        require 'puppetfile-resolver'

        return new unless path.exist?

        begin
          parsed = ::PuppetfileResolver::Puppetfile::Parser::R10KEval.parse(File.read(path))
        rescue StandardError => e
          raise Bolt::Error.new(
            "Unable to parse Puppetfile #{path}: #{e.message}",
            'bolt/puppetfile-parsing'
          )
        end

        unless parsed.valid?
          raise Bolt::ValidationError, <<~MSG
            Unable to parse Puppetfile #{path}:
            #{parsed.validation_errors.join("\n\n")}.
            This Puppetfile might not be managed by Bolt.
          MSG
        end

        modules = parsed.modules.each_with_object([]) do |mod, acc|
          case mod.module_type
          when :forge
            acc << ForgeModule.new(
              mod.title,
              mod.version.is_a?(String) ? mod.version[1..-1] : nil
            )
          when :git
            acc << GitModule.new(
              mod.name,
              mod.remote,
              mod.ref || mod.commit || mod.tag
            )
          else
            unless skip_unsupported_modules
              raise Bolt::ValidationError,
                    "Cannot parse Puppetfile at #{path}, module '#{mod.title}' is not a "\
                    "Puppet Forge or Git module."
            end
          end
        end

        new(modules)
      end

      # Writes a Puppetfile that includes specifications for each of the
      # modules.
      #
      def write(path, moduledir = nil)
        File.open(path, 'w') do |file|
          if moduledir
            file.puts "# This Puppetfile is managed by Bolt. Do not edit."
            file.puts "# For more information, see https://pup.pt/bolt-modules"
            file.puts
            file.puts "# The following directive installs modules to the managed moduledir."
            file.puts "moduledir '#{moduledir.basename}'"
            file.puts
          end

          @modules.each { |mod| file.puts mod.to_spec }
        end
      rescue SystemCallError => e
        raise Bolt::FileError.new(
          "#{e.message}: unable to write Puppetfile.",
          path
        )
      end

      # Asserts that the Puppetfile satisfies the given specifications.
      #
      def assert_satisfies(specs)
        unsatisfied_specs = specs.specs.reject do |spec|
          @modules.any? do |mod|
            spec.satisfied_by?(mod)
          end
        end

        versionless_mods = @modules.select { |mod| mod.is_a?(ForgeModule) && mod.version.nil? }
        command = Bolt::Util.windows? ? 'Install-BoltModule -Force' : 'bolt module install --force'

        if unsatisfied_specs.any?
          message = <<~MESSAGE.chomp
            Puppetfile does not include modules that satisfy the following specifications:

            #{unsatisfied_specs.map(&:to_hash).to_yaml.lines.drop(1).join.chomp}
            
            This Puppetfile might not be managed by Bolt. To forcibly overwrite the
            Puppetfile, run '#{command}'.
          MESSAGE

          raise Bolt::Error.new(message, 'bolt/missing-module-specs')
        end

        if versionless_mods.any?
          message = <<~MESSAGE.chomp
            Puppetfile includes Forge modules without a version requirement:
            
            #{versionless_mods.map(&:to_spec).join.chomp}
            
            This Puppetfile might not be managed by Bolt. To forcibly overwrite the
            Puppetfile, run '#{command}'.
          MESSAGE

          raise Bolt::Error.new(message, 'bolt/missing-module-version-specs')
        end
      end
    end
  end
end
