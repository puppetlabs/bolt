# frozen_string_literal: true

require_relative 'project_manager/config_migrator'
require_relative 'project_manager/inventory_migrator'
require_relative 'project_manager/module_migrator'

module Bolt
  class ProjectManager
    INVENTORY_TEMPLATE = <<~INVENTORY
      # This is an example inventory.yaml
      # To read more about inventory files, see https://pup.pt/bolt-inventory
      #
      # groups:
      #   - name: linux
      #     targets:
      #       - target1.example.com
      #       - target2.example.com
      #     config:
      #       transport: ssh
      #       ssh:
      #         private-key: /path/to/private_key.pem
      #   - name: windows
      #     targets:
      #       - name: win1
      #         uri: target3.example.com
      #       - name: win2
      #         uri: target4.example.com
      #     config:
      #       transport: winrm
      # config:
      #   ssh:
      #     host-key-check: false
      #   winrm:
      #     user: Administrator
      #     password: Bolt!
      #     ssl: false
    INVENTORY

    GITIGNORE_CONTENT = <<~GITIGNORE
      .modules/
      .resource_types/
      bolt-debug.log
      .plan_cache.json
      .plugin_cache.json
      .task_cache.json
      .rerun.json
    GITIGNORE

    def initialize(config, outputter, pal)
      @config    = config
      @outputter = outputter
      @pal       = pal
    end

    # Creates a new project at the specified directory.
    #
    def create(path, name, modules)
      require_relative '../bolt/module_installer'

      project       = Pathname.new(File.expand_path(path))
      old_config    = project + 'bolt.yaml'
      config        = project + 'bolt-project.yaml'
      puppetfile    = project + 'Puppetfile'
      moduledir     = project + '.modules'
      inventoryfile = project + 'inventory.yaml'
      gitignore     = project + '.gitignore'
      project_name  = name || File.basename(project)

      if config.exist?
        if modules
          command = Bolt::Util.powershell? ? 'Add-BoltModule -Module' : 'bolt module add'
          raise Bolt::Error.new(
            "Found existing project directory with #{config.basename} at #{project}, "\
            "unable to initialize project with modules. To add modules to the project, "\
            "run '#{command} <module>' instead.",
            'bolt/existing-project-error'
          )
        else
          raise Bolt::Error.new(
            "Found existing project directory with #{config.basename} at #{project}, "\
            "unable to initialize project.",
            'bolt/existing-project-error'
          )
        end
      elsif old_config.exist?
        command = Bolt::Util.powershell? ? 'Update-BoltProject' : 'bolt project migrate'
        raise Bolt::Error.new(
          "Found existing project directory with #{old_config.basename} at #{project}, "\
          "unable to initialize project. #{old_config.basename} is deprecated. To "\
          "update the project to current best practices, run '#{command}'.",
          'bolt/existing-project-error'
        )
      elsif modules && puppetfile.exist?
        raise Bolt::Error.new(
          "Found existing Puppetfile at #{puppetfile}, unable to initialize project "\
          "with modules.",
          'bolt/existing-puppetfile-error'
        )
      elsif project_name !~ Bolt::Module::MODULE_NAME_REGEX
        if name
          raise Bolt::ValidationError,
                "The provided project name '#{project_name}' is invalid; project name must "\
                "begin with a lowercase letter and can include lowercase letters, "\
                "numbers, and underscores."
        else
          command = Bolt::Util.powershell? ? 'New-BoltProject -Name' : 'bolt project init'
          raise Bolt::ValidationError,
                "The current directory name '#{project_name}' is an invalid project name. "\
                "Please specify a name using '#{command} <name>'."
        end
      end

      # If modules were specified, resolve and install first. We want to error
      # early here and not initialize the project if the modules cannot be
      # resolved and installed.
      if modules
        @outputter.start_spin
        Bolt::ModuleInstaller.new(@outputter, @pal).install(modules, puppetfile, moduledir)
        @outputter.stop_spin
      end

      data = { 'name' => project_name }
      data['modules'] = modules || []

      begin
        File.write(config.to_path, data.to_yaml)
      rescue StandardError => e
        raise Bolt::FileError.new("Could not create bolt-project.yaml at #{project}: #{e.message}", nil)
      end

      unless inventoryfile.exist?
        begin
          File.write(inventoryfile.to_path, INVENTORY_TEMPLATE)
        rescue StandardError => e
          raise Bolt::FileError.new("Could not create inventory.yaml at #{project}: #{e.message}", nil)
        end
      end

      unless gitignore.exist?
        begin
          File.write(gitignore.to_path, GITIGNORE_CONTENT)
        rescue StandardError => e
          raise Bolt::FileError.new("Could not create .gitignore at #{project}: #{e.message}", nil)
        end
      end

      @outputter.print_message("Successfully created Bolt project at #{project}")

      0
    end

    # Migrates a project to use the latest file versions and best practices.
    #
    def migrate
      unless $stdin.tty?
        raise Bolt::Error.new(
          "stdin is not a tty, unable to migrate project",
          'bolt/stdin-not-a-tty-error'
        )
      end

      @outputter.print_message("Migrating project #{@config.project.path}\n\n")

      @outputter.print_action_step(
        "Migrating a Bolt project might make irreversible changes to the project's "\
        "configuration and inventory files. Before continuing, make sure the "\
        "project has a backup or uses a version control system."
      )

      return 0 unless Bolt::Util.prompt_yes_no("Continue with project migration?", @outputter)

      @outputter.print_message('')

      ok = migrate_inventory && migrate_config && migrate_modules

      if ok
        @outputter.print_message("Project successfully migrated")
      else
        @outputter.print_error("Project could not be migrated completely")
      end

      ok ? 0 : 1
    end

    # Migrates the project-level configuration file to the latest version.
    #
    private def migrate_config
      migrator   = ConfigMigrator.new(@outputter)
      configfile = @config.project.path + 'bolt.yaml'

      migrator.migrate(
        configfile,
        @config.project.project_file,
        @config.inventoryfile || @config.project.inventory_file,
        @config.project.backup_dir
      )
    end

    # Migrates the inventory file to the latest version.
    #
    private def migrate_inventory
      migrator = InventoryMigrator.new(@outputter)

      migrator.migrate(
        @config.inventoryfile || @config.project.inventory_file,
        @config.project.backup_dir
      )
    end

    # Migrates the project's modules to use current best practices.
    #
    private def migrate_modules
      migrator = ModuleMigrator.new(@outputter)

      migrator.migrate(
        @config.project,
        @config.modulepath[0...-1]
      )
    end
  end
end
