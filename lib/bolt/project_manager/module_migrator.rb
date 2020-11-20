# frozen_string_literal: true

require 'bolt/project_manager/migrator'

module Bolt
  class ProjectManager
    class ModuleMigrator < Migrator
      def migrate(project, configured_modulepath)
        return true unless project.modules.nil?

        @outputter.print_message "Migrating project modules\n\n"

        config            = project.project_file
        puppetfile        = project.puppetfile
        managed_moduledir = project.managed_moduledir
        modulepath        = [(project.path + 'modules').to_s,
                             (project.path + 'site-modules').to_s,
                             (project.path + 'site').to_s]

        # Notify user to manually migrate modules if using non-default modulepath
        if configured_modulepath != modulepath
          @outputter.print_action_step(
            "Project has a non-default configured modulepath, unable to automatically "\
            "migrate project modules. To migrate project modules manually, see "\
            "http://pup.pt/bolt-modules"
          )
          true
        # Migrate modules from Puppetfile
        elsif File.exist?(puppetfile)
          migrate_modules_from_puppetfile(config, puppetfile, managed_moduledir, modulepath)
        # Migrate modules to updated modulepath
        else
          consolidate_modules(modulepath)
          update_project_config([], config)
        end
      end

      # Migrates modules by reading a Puppetfile and prompting the user for
      # which ones are direct dependencies for the project. Once the user has
      # selected the direct dependencies, this will resolve the modules, write a
      # new Puppetfile, install the modules, and then move any remaining modules
      # to the new moduledir.
      #
      private def migrate_modules_from_puppetfile(config, puppetfile_path, managed_moduledir, modulepath)
        require 'bolt/module_installer/installer'
        require 'bolt/module_installer/puppetfile'
        require 'bolt/module_installer/resolver'
        require 'bolt/module_installer/specs'

        begin
          @outputter.print_action_step("Parsing Puppetfile at #{puppetfile_path}")
          puppetfile = Bolt::ModuleInstaller::Puppetfile.parse(puppetfile_path, skip_unsupported_modules: true)
        rescue Bolt::Error => e
          @outputter.print_action_error("#{e.message}\nSkipping module migration.")
          return false
        end

        # Prompt for direct dependencies
        modules = select_modules(puppetfile.modules)

        # Create specs to resolve from
        specs = Bolt::ModuleInstaller::Specs.new(modules.map(&:to_hash))

        # Attempt to resolve dependencies
        begin
          @outputter.print_message('')
          @outputter.print_action_step("Resolving module dependencies, this may take a moment")
          puppetfile = Bolt::ModuleInstaller::Resolver.new.resolve(specs)
        rescue Bolt::Error => e
          @outputter.print_action_error("#{e.message}\nSkipping module migration.")
          return false
        end

        migrate_managed_modules(puppetfile, puppetfile_path, managed_moduledir)

        # Move remaining modules to 'modules'
        consolidate_modules(modulepath)

        # Delete old modules that are now managed
        delete_modules(modulepath.first, puppetfile.modules)

        # Add modules to project
        update_project_config(modules.map(&:to_hash), config)
      end

      # Migrates the managed modules. If modules were selected to be managed,
      # the Puppetfile is rewritten and modules are installed. If no modules
      # were selected, the Puppetfile is deleted.
      #
      private def migrate_managed_modules(puppetfile, puppetfile_path, managed_moduledir)
        if puppetfile.modules.any?
          # Show the new Puppetfile content
          message  = "Generated new Puppetfile content:\n\n"
          message += puppetfile.modules.map(&:to_spec).join("\n").to_s
          @outputter.print_action_step(message)

          # Write Puppetfile
          @outputter.print_action_step("Updating Puppetfile at #{puppetfile_path}")
          puppetfile.write(puppetfile_path, managed_moduledir)

          # Install Puppetfile
          @outputter.print_action_step("Syncing modules from #{puppetfile_path} to #{managed_moduledir}")
          Bolt::ModuleInstaller::Installer.new.install(puppetfile_path, managed_moduledir)
        else
          @outputter.print_action_step(
            "Project does not include any managed modules, deleting Puppetfile "\
            "at #{puppetfile_path}"
          )
          FileUtils.rm(puppetfile_path)
        end
      end

      # Prompts the user to select modules, returning a list of
      # the selected modules.
      #
      private def select_modules(modules)
        @outputter.print_action_step(
          "Select modules that are direct dependencies of your project. Bolt will "\
          "automatically manage dependencies for each module selected, so do not "\
          "select a module's dependencies unless you use content from it directly "\
          "in your project."
        )

        all = Bolt::Util.prompt_yes_no("Select all modules?", @outputter)
        return modules if all

        modules.select do |mod|
          Bolt::Util.prompt_yes_no("Select #{mod.full_name}?", @outputter)
        end
      end

      # Consolidates all modules on the modulepath to 'modules'.
      #
      private def consolidate_modules(modulepath)
        moduledir, *sources = modulepath

        sources.select! { |source| Dir.exist?(source) }

        if sources.any?
          @outputter.print_action_step(
            "Moving modules from #{sources.join(', ')} to #{moduledir}"
          )

          FileUtils.mkdir_p(moduledir)
          move_modules(moduledir, sources)
        end
      end

      # Moves modules from a list of source directories to the specified
      # moduledir, deleting the source directory after it's done.
      #
      private def move_modules(moduledir, sources)
        moduledir = Pathname.new(moduledir)

        sources.each do |source|
          source = Pathname.new(source)

          source.each_child do |mod|
            next unless mod.directory?
            next if (moduledir + mod.basename).directory?
            FileUtils.mv(mod, moduledir)
          end

          FileUtils.rm_r(source)
        end
      end

      # Deletes modules from a specified directory.
      #
      private def delete_modules(moduledir, modules)
        @outputter.print_action_step("Cleaning up #{moduledir}")
        moduledir = Pathname.new(moduledir)

        modules.each do |mod|
          path = moduledir + mod.name
          FileUtils.rm_r(path) if path.directory?
        end
      end

      # Adds a list of modules to the project configuration file.
      #
      private def update_project_config(modules, config_file)
        @outputter.print_action_step("Updating project configuration at #{config_file}")
        data = Bolt::Util.read_optional_yaml_hash(config_file, 'project')
        data.merge!('modules' => modules)
        data.delete('modulepath')

        begin
          File.write(config_file, data.to_yaml)
          true
        rescue StandardError => e
          raise Bolt::FileError.new(
            "Unable to write to #{config_file}: #{e.message}",
            config_file
          )
        end
      end
    end
  end
end
