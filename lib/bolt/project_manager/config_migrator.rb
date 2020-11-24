# frozen_string_literal: true

require 'bolt/project_manager/migrator'

module Bolt
  class ProjectManager
    class ConfigMigrator < Migrator
      def migrate(config_file, project_file, inventory_file, backup_dir)
        bolt_yaml_to_bolt_project(config_file, project_file, inventory_file, backup_dir) &&
          update_options(project_file)
      end

      private def bolt_yaml_to_bolt_project(config_file, project_file, inventory_file, backup_dir)
        if File.exist?(project_file)
          return true
        end

        unless File.exist?(config_file)
          return true
        end

        @outputter.print_message "Migrating project configuration\n\n"

        config_data = Bolt::Util.read_optional_yaml_hash(config_file, 'config')
        transport_data, project_data = config_data.partition do |k, _|
          Bolt::Config::INVENTORY_OPTIONS.keys.include?(k)
        end.map(&:to_h)

        if transport_data.any?
          if File.exist?(inventory_file)
            inventory_data = Bolt::Util.read_yaml_hash(inventory_file, 'inventory')
            merged = Bolt::Util.deep_merge(transport_data, inventory_data['config'] || {})
            inventory_data['config'] = merged
            backup_file(inventory_file, backup_dir)
          else
            FileUtils.touch(inventory_file)
            inventory_data = { 'config' => transport_data }
          end

          backup_file(config_file, backup_dir)

          begin
            @outputter.print_action_step(
              "Moving transportation configuration options '#{transport_data.keys.join(', ')}' "\
              "from bolt.yaml to inventory.yaml"
            )

            File.write(inventory_file, inventory_data.to_yaml)
            File.write(config_file, project_data.to_yaml)
          rescue StandardError => e
            raise Bolt::FileError.new("#{e.message}; unable to write inventory.", inventory_file)
          end
        end

        @outputter.print_action_step("Renaming bolt.yaml to bolt-project.yaml")
        FileUtils.mv(config_file, project_file)

        command = Bolt::Util.powershell? ? 'Get-Help about_bolt_project' : 'bolt guide project'
        @outputter.print_action_step(
          "Successfully migrated config. Please add a 'name' key to bolt-project.yaml "\
          "to use project-level tasks and plans. Learn more about projects by running "\
          "'#{command}'."
        )

        true
      end

      private def update_options(project_file)
        return true unless File.exist?(project_file)

        @outputter.print_message("Updating project configuration options\n\n")
        data     = Bolt::Util.read_yaml_hash(project_file, 'config')
        modified = false

        if data.key?('plugin_hooks') && !data.key?('plugin-hooks')
          @outputter.print_action_step("Updating 'plugin_hooks' option to 'plugin-hooks'")
          data['plugin-hooks'] = data.delete('plugin_hooks')
          modified = true
        end

        if modified
          begin
            File.write(project_file, data.to_yaml)
          rescue StandardError => e
            raise Bolt::FileError.new("#{e.message}; unable to write config.", project_file)
          end

          @outputter.print_action_step("Successfully updated project configuration #{project_file}")
        else
          @outputter.print_action_step("Project configuration is up to date, nothing to do.")
        end

        true
      end
    end
  end
end
