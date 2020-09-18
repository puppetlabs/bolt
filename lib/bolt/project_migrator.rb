# frozen_string_literal: true

require 'bolt/project_migrator/config'
require 'bolt/project_migrator/inventory'

module Bolt
  class ProjectMigrator
    def initialize(config, outputter)
      @config    = config
      @outputter = outputter
    end

    def migrate
      unless $stdin.tty?
        raise Bolt::Error.new(
          "stdin is not a tty, unable to migrate project",
          'bolt/stdin-not-a-tty-error'
        )
      end

      @outputter.print_message("Migrating project #{@config.project.path}\n\n")

      @outputter.print_migrate_step(
        "Migrating a Bolt project may make irreversible changes to the project's "\
        "configuration and inventory files. Before continuing, make sure the "\
        "project has a backup or uses a version control system."
      )

      return 0 unless Bolt::Util.prompt_yes_no("Continue with project migration?", @outputter)

      ok = migrate_inventory && migrate_config

      if ok
        @outputter.print_message("Project successfully migrated")
      else
        @outputter.print_message("Project could not be migrated")
      end

      ok ? 0 : 1
    end

    # Migrates the project-level configuration file to the latest version.
    #
    private def migrate_config
      migrator = Bolt::ProjectMigrator::Config.new(@outputter)

      migrator.migrate(
        @config.project.config_file,
        @config.project.project_file,
        @config.inventoryfile || @config.project.inventory_file,
        @config.project.backup_dir
      )
    end

    # Migrates the inventory file to the latest version.
    #
    private def migrate_inventory
      migrator = Bolt::ProjectMigrator::Inventory.new(@outputter)

      migrator.migrate(
        @config.inventoryfile || @config.project.inventory_file,
        @config.project.backup_dir
      )
    end
  end
end
