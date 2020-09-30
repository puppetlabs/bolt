# frozen_string_literal: true

require 'bolt/error'
require 'bolt/logger'

module Bolt
  class ModuleInstaller
    def initialize(outputter, pal)
      @outputter = outputter
      @pal       = pal
      @logger    = Bolt::Logger.logger(self)
    end

    # Adds a single module to the project.
    #
    def add(name, modules, puppetfile_path, moduledir, config_path)
      require 'bolt/puppetfile'

      # If the project configuration file already includes this module,
      # exit early.
      puppetfile  = Bolt::Puppetfile.new(modules)
      new_module  = Bolt::Puppetfile::Module.from_hash('name' => name)

      if puppetfile.modules.include?(new_module)
        @outputter.print_message "Project configuration file #{config_path} already "\
                                 "includes module #{new_module}. Nothing to do."
        return true
      end

      # If the Puppetfile exists, make sure it's managed by Bolt.
      if puppetfile_path.exist?
        assert_managed_puppetfile(puppetfile, puppetfile_path)
      end

      # Create a Puppetfile object that includes the new module and its
      # dependencies. We error early here so we don't add the new module to the
      # project config or modify the Puppetfile.
      puppetfile = add_new_module_to_puppetfile(new_module, modules, puppetfile_path)

      # Add the module to the project configuration.
      @outputter.print_message "Updating project configuration file at #{config_path}"

      data = Bolt::Util.read_yaml_hash(config_path, 'project')
      data['modules'] ||= []
      data['modules'] <<  { 'name' => new_module.title }

      begin
        File.write(config_path, data.to_yaml)
      rescue SystemCallError => e
        raise Bolt::FileError.new(
          "Unable to update project configuration file: #{e.message}",
          config
        )
      end

      # Write the Puppetfile.
      @outputter.print_message "Writing Puppetfile at #{puppetfile_path}"
      puppetfile.write(puppetfile_path, moduledir)

      # Install the modules.
      install_puppetfile(puppetfile_path, moduledir)
    end

    # Creates a new Puppetfile that includes the new module and its dependencies.
    #
    private def add_new_module_to_puppetfile(new_module, modules, path)
      @outputter.print_message "Resolving module dependencies, this may take a moment"

      # If there is an existing Puppetfile, add the new module and attempt
      # to resolve. This will not update the versions of any installed modules.
      if path.exist?
        puppetfile = Bolt::Puppetfile.parse(path)
        puppetfile.add_modules(new_module)

        begin
          puppetfile.resolve
          return puppetfile
        rescue Bolt::Error
          @logger.debug "Unable to find a version of #{new_module} compatible "\
                        "with installed modules. Attempting to re-resolve modules "\
                        "from project configuration; some versions of installed "\
                        "modules may change."
        end
      end

      # If there is not an existing Puppetfile, or resolving with pinned
      # modules fails, resolve all of the module declarations with the new
      # module.
      puppetfile = Bolt::Puppetfile.new(modules)
      puppetfile.add_modules(new_module)
      puppetfile.resolve
      puppetfile
    end

    # Installs a project's module dependencies.
    #
    def install(modules, path, moduledir, force: false, resolve: true)
      require 'bolt/puppetfile'

      puppetfile = Bolt::Puppetfile.new(modules)

      # If the Puppetfile exists, check if it includes specs for each declared
      # module, erroring if there are any missing. Otherwise, resolve the
      # module dependencies and write a new Puppetfile. Users can forcibly
      # overwrite an existing Puppetfile with the '--force' option, or opt to
      # install the Puppetfile as-is with --no-resolve.
      #
      # This is just if resolve is not false (nil should default to true)
      if resolve != false
        if path.exist? && !force
          assert_managed_puppetfile(puppetfile, path)
        else
          @outputter.print_message "Resolving module dependencies, this may take a moment"
          puppetfile.resolve

          @outputter.print_message "Writing Puppetfile at #{path}"
          # We get here either through 'bolt module install' which uses the
          # managed modulepath (which isn't configurable) or through bolt
          # project init --modules, which uses the default modulepath. This
          # should be safe to assume that if `.modules/` is the moduledir the
          # user is using the new workflow
          if moduledir.basename == '.modules'
            puppetfile.write(path, moduledir)
          else
            puppetfile.write(path)
          end
        end
      end

      # Install the modules.
      install_puppetfile(path, moduledir)
    end

    # Installs the Puppetfile and generates types.
    #
    def install_puppetfile(path, moduledir, config = {})
      require 'bolt/puppetfile/installer'

      @outputter.print_message "Syncing modules from #{path} to #{moduledir}"
      ok = Bolt::Puppetfile::Installer.new(config).install(path, moduledir)

      # Automatically generate types after installing modules
      @pal.generate_types

      @outputter.print_puppetfile_result(ok, path, moduledir)

      ok
    end

    # Asserts that an existing Puppetfile is managed by Bolt.
    #
    private def assert_managed_puppetfile(puppetfile, path)
      existing_puppetfile = Bolt::Puppetfile.parse(path)

      unless existing_puppetfile.modules.superset? puppetfile.modules
        missing_modules = puppetfile.modules - existing_puppetfile.modules

        message = <<~MESSAGE.chomp
          Puppetfile #{path} is missing specifications for the following
          module declarations:

          #{missing_modules.map(&:to_hash).to_yaml.lines.drop(1).join.chomp}
          
          This may not be a Puppetfile managed by Bolt. To forcibly overwrite the
          Puppetfile, run 'bolt module install --force'.
        MESSAGE

        raise Bolt::Error.new(message, 'bolt/missing-module-specs')
      end
    end
  end
end
