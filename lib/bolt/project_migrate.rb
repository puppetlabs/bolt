# frozen_string_literal: true

module Bolt
  class ProjectMigrate
    attr_reader :path, :project_file, :backup_dir, :outputter, :inventory_file, :config_file

    # This init mostly makes testing easier
    def initialize(path, outputter, configured_inventory = nil)
      @path = Pathname.new(path).expand_path
      @project_file = @path + 'bolt-project.yaml'
      @config_file = @path + 'bolt.yaml'
      @backup_dir = @path + '.bolt-bak'
      @inventory_file = configured_inventory || @path + 'inventory.yaml'
      @outputter = outputter
    end

    def migrate_project
      inv_ok = inventory_1_to_2(inventory_file, outputter) if inventory_file.file?
      config_ok = bolt_yaml_to_bolt_project(inventory_file, outputter)
      inv_ok && config_ok ? 0 : 1
    end

    # This could be made public and used elsewhere if the need arises
    private def backup_file(origin_path)
      unless File.exist?(origin_path)
        outputter.print_message "Could not find file #{origin_path}, skipping backup."
        return
      end

      date = Time.new.strftime("%Y%m%d_%H%M%S%L")
      FileUtils.mkdir_p(backup_dir)

      filename = File.basename(origin_path)
      backup_path = File.join(backup_dir, "#{filename}.#{date}.bak")

      outputter.print_message "Backing up #{filename} from #{origin_path} to #{backup_path}"

      begin
        FileUtils.cp(origin_path, backup_path)
      rescue StandardError => e
        raise Bolt::FileError.new("#{e.message}; unable to create backup of #{filename}.", origin_path)
      end
    end

    private def bolt_yaml_to_bolt_project(inventory_file, outputter)
      # If bolt-project.yaml already exists
      if project_file.file?
        outputter.print_message "bolt-project.yaml already exists in Bolt "\
          "project at #{path}. Skipping project file update."

      # If bolt.yaml doesn't exist
      elsif !config_file.file?
        outputter.print_message "Could not find bolt.yaml in project at "\
          "#{path}. Skipping project file update."

      else
        config_data = Bolt::Util.read_optional_yaml_hash(config_file, 'config')
        transport_data, project_data = config_data.partition do |k, _|
          Bolt::Config::INVENTORY_OPTIONS.keys.include?(k)
        end.map(&:to_h)

        if transport_data.any?
          if File.exist?(inventory_file)
            inventory_data = Bolt::Util.read_yaml_hash(inventory_file, 'inventory')
            merged = Bolt::Util.deep_merge(transport_data, inventory_data['config'] || {})
            inventory_data['config'] = merged
            backup_file(inventory_file)
          else
            FileUtils.touch(inventory_file)
            inventory_data = { 'config' => transport_data }
          end

          backup_file(config_file)

          begin
            outputter.print_message "Moving transportation configuration options "\
              "'#{transport_data.keys.join(', ')}' from bolt.yaml to inventory.yaml"
            File.write(inventory_file, inventory_data.to_yaml)
            File.write(config_file, project_data.to_yaml)
          rescue StandardError => e
            raise Bolt::FileError.new("#{e.message}; unable to write inventory.", inventory_file)
          end
        end

        outputter.print_message "Renaming bolt.yaml to bolt-project.yaml"
        FileUtils.mv(config_file, project_file)
        outputter.print_message "Successfully updated project. Please add a "\
          "'name' key to bolt-project.yaml to use project-level tasks and plans. "\
          "Learn more about projects by running 'bolt guide project'."
        # If nothing errored, this succeeded
        true
      end
    end

    private def inventory_1_to_2(inventory_file, outputter)
      data = Bolt::Util.read_yaml_hash(inventory_file, 'inventory')
      data.delete('version') if data['version'] != 2
      migrated = migrate_group(data)

      ok = if migrated
             backup_file(inventory_file)
             File.write(inventory_file, data.to_yaml)
           end

      result = if migrated && ok
                 "Successfully migrated Bolt inventory to the latest version."
               elsif !migrated
                 "Bolt inventory is already on the latest version. Skipping inventory update."
               else
                 "Could not migrate Bolt inventory to the latest version. See "\
                 "https://puppet.com/docs/bolt/latest/inventory_file_v2.html to manually update."
               end
      outputter.print_message(result)
      ok
    end

    # Walks an inventory hash and replaces all 'nodes' keys with 'targets' keys
    # and all 'name' keys nested in a 'targets' hash with 'uri' keys. Data is
    # modified in place.
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
