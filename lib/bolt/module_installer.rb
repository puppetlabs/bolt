# frozen_string_literal: true

require 'bolt/error'
require 'bolt/logger'
require 'bolt/module_installer/installer'
require 'bolt/module_installer/puppetfile'
require 'bolt/module_installer/resolver'
require 'bolt/module_installer/specs'

module Bolt
  class ModuleInstaller
    def initialize(outputter, pal)
      @outputter = outputter
      @pal       = pal
      @logger    = Bolt::Logger.logger(self)
    end

    # Adds a single module to the project.
    #
    def add(name, specs, puppetfile_path, moduledir, project_file, config)
      project_specs = Specs.new(specs)

      # Exit early if project config already includes a spec with this name.
      if project_specs.include?(name)
        @outputter.print_message(
          "Project configuration file #{project_file} already includes specification "\
          "with name #{name}. Nothing to do."
        )
        return true
      end

      @outputter.print_message("Adding module #{name} to project\n\n")

      # Generate the specs to resolve from. If a Puppetfile exists, parse it and
      # convert the modules to specs. Otherwise, use the project specs.
      resolve_specs = if puppetfile_path.exist?
                        existing_puppetfile = Puppetfile.parse(puppetfile_path)
                        existing_puppetfile.assert_satisfies(project_specs)
                        Specs.from_puppetfile(existing_puppetfile)
                      else
                        project_specs
                      end

      # Resolve module dependencies. Attempt to first resolve with resolve
      # specss. If that fails, fall back to resolving from project specs.
      # This prevents Bolt from modifying installed modules unless there is
      # a version conflict.
      @outputter.print_action_step("Resolving module dependencies, this might take a moment")

      @outputter.start_spin
      begin
        resolve_specs.add_specs('name' => name)
        puppetfile = Resolver.new.resolve(resolve_specs, config)
      rescue Bolt::Error
        project_specs.add_specs('name' => name)
        puppetfile = Resolver.new.resolve(project_specs, config)
      end
      @outputter.stop_spin

      # Display the diff between the existing Puppetfile and the new Puppetfile.
      print_puppetfile_diff(existing_puppetfile, puppetfile)

      # Add the module to the project configuration.
      @outputter.print_action_step("Updating project configuration file at #{project_file}")

      data = Bolt::Util.read_yaml_hash(project_file, 'project')
      data['modules'] ||= []
      data['modules'] << name.tr('-', '/')

      begin
        File.write(project_file, data.to_yaml)
      rescue SystemCallError => e
        raise Bolt::FileError.new(
          "Unable to update project configuration file: #{e.message}",
          project_file
        )
      end

      # Write the Puppetfile.
      @outputter.print_action_step("Writing Puppetfile at #{puppetfile_path}")
      puppetfile.write(puppetfile_path, moduledir)

      # Install the modules.
      install_puppetfile(puppetfile_path, moduledir, config)
    end

    # Outputs a diff of an old Puppetfile and a new Puppetfile.
    #
    def print_puppetfile_diff(old, new)
      # Build hashes mapping the module name to the module object. This makes it
      # a little easier to determine which modules have been added, removed, or
      # modified.
      old = (old&.modules || []).each_with_object({}) do |mod, acc|
        next unless mod.type == :forge
        acc[mod.full_name] = mod
      end

      new = new.modules.each_with_object({}) do |mod, acc|
        next unless mod.type == :forge
        acc[mod.full_name] = mod
      end

      # New modules are those present in new but not in old.
      added = new.reject { |full_name, _mod| old.include?(full_name) }.values

      if added.any?
        diff = "Adding the following modules:\n"
        added.each { |mod| diff += "#{mod.full_name} #{mod.version}\n" }
        @outputter.print_action_step(diff)
      end

      # Upgraded modules are those that have a newer version in new than old.
      upgraded = new.select do |full_name, mod|
        if old.include?(full_name)
          mod.version > old[full_name].version
        end
      end.keys

      if upgraded.any?
        diff = "Upgrading the following modules:\n"
        upgraded.each { |full_name| diff += "#{full_name} #{old[full_name].version} to #{new[full_name].version}\n" }
        @outputter.print_action_step(diff)
      end

      # Downgraded modules are those that have an older version in new than old.
      downgraded = new.select do |full_name, mod|
        if old.include?(full_name)
          mod.version < old[full_name].version
        end
      end.keys

      if downgraded.any?
        diff = "Downgrading the following modules: \n"
        downgraded.each { |full_name| diff += "#{full_name} #{old[full_name].version} to #{new[full_name].version}\n" }
        @outputter.print_action_step(diff)
      end

      # Removed modules are those present in old but not in new.
      removed = old.reject { |full_name, _mod| new.include?(full_name) }.values

      if removed.any?
        diff = "Removing the following modules:\n"
        removed.each { |mod| diff += "#{mod.full_name} #{mod.version}\n" }
        @outputter.print_action_step(diff)
      end
    end

    # Installs a project's module dependencies.
    #
    def install(specs, path, moduledir, config = {}, force: false, resolve: true)
      @outputter.print_message("Installing project modules\n\n")

      if resolve != false
        specs = Specs.new(specs)

        # If forcibly installing or if there is no Puppetfile, resolve
        # and write a Puppetfile.
        if force || !path.exist?
          @outputter.print_action_step("Resolving module dependencies, this might take a moment")

          # This doesn't use the block as it's more testable to just mock *_spin
          @outputter.start_spin
          puppetfile = Resolver.new.resolve(specs, config)
          @outputter.stop_spin

          # We get here either through 'bolt module install' which uses the
          # managed modulepath (which isn't configurable) or through bolt
          # project init --modules, which uses the default modulepath. This
          # should be safe to assume that if `.modules/` is the moduledir the
          # user is using the new workflow
          @outputter.print_action_step("Writing Puppetfile at #{path}")
          if moduledir.basename.to_s == '.modules'
            puppetfile.write(path, moduledir)
          else
            puppetfile.write(path)
          end
        # If not forcibly installing and there is a Puppetfile, assert
        # that it satisfies the specs.
        else
          puppetfile = Puppetfile.parse(path)
          puppetfile.assert_satisfies(specs)
        end
      end

      # Install the modules.
      install_puppetfile(path, moduledir, config)
    end

    # Installs the Puppetfile and generates types.
    #
    def install_puppetfile(path, moduledir, config = {})
      @outputter.print_action_step("Syncing modules from #{path} to #{moduledir}")
      @outputter.start_spin
      ok = Installer.new(config).install(path, moduledir)
      @outputter.stop_spin

      # Automatically generate types after installing modules
      if ok
        @outputter.print_action_step("Generating type references")
        @pal.generate_types(cache: true)
      end

      @outputter.print_puppetfile_result(ok, path, moduledir)

      ok
    end
  end
end
