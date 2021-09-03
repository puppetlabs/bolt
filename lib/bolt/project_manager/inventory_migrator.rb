# frozen_string_literal: true

require_relative '../../bolt/project_manager/migrator'

module Bolt
  class ProjectManager
    class InventoryMigrator < Migrator
      def migrate(inventory_file, backup_dir)
        inventory1to2(inventory_file, backup_dir)
      end

      # Migrates an inventory v1 file to inventory v2.
      #
      private def inventory1to2(inventory_file, backup_dir)
        unless File.exist?(inventory_file)
          return true
        end

        data = Bolt::Util.read_yaml_hash(inventory_file, 'inventory')
        data.delete('version') if data['version'] != 2
        migrated = migrate_group(data)

        return true unless migrated

        @outputter.print_message "Migrating inventory\n\n"

        backup_file(inventory_file, backup_dir)

        begin
          File.write(inventory_file, data.to_yaml)
          @outputter.print_action_step(
            "Successfully migrated Bolt inventory to the latest version."
          )
          true
        rescue StandardError => e
          raise Bolt::FileError.new(
            "Unable to write to #{inventory_file}: #{e.message}. See "\
            "http://pup.pt/bolt-inventory to manually update.",
            inventory_file
          )
        end
      end

      # Walks an inventory hash and replaces all 'nodes' keys with 'targets'
      # keys and all 'name' keys nested in a 'targets' hash with 'uri' keys.
      # Data is modified in place.
      #
      private def migrate_group(group)
        migrated = false
        if group.key?('nodes')
          migrated = true
          targets = group['nodes'].map do |target|
            target['uri'] = target.delete('name') if target.is_a?(Hash)
            target
          end
          group.delete('nodes')
          group['targets'] = targets
        end
        (group['groups'] || []).each do |subgroup|
          migrated_group = migrate_group(subgroup)
          migrated ||= migrated_group
        end
        migrated
      end
    end
  end
end
