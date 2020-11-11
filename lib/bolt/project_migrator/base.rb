# frozen_string_literal: true

require 'fileutils'
require 'bolt/error'

module Bolt
  class ProjectMigrator
    class Base
      def initialize(outputter)
        @outputter = outputter
      end

      protected def backup_file(origin_path, backup_dir)
        unless File.exist?(origin_path)
          @outputter.print_action_step(
            "Could not find file #{origin_path}, skipping backup."
          )
          return
        end

        date = Time.new.strftime("%Y%m%d_%H%M%S%L")
        FileUtils.mkdir_p(backup_dir)

        filename = File.basename(origin_path)
        backup_path = File.join(backup_dir, "#{filename}.#{date}.bak")

        @outputter.print_action_step(
          "Backing up #{filename} from #{origin_path} to #{backup_path}"
        )

        begin
          FileUtils.cp(origin_path, backup_path)
        rescue StandardError => e
          raise Bolt::FileError.new("#{e.message}; unable to create backup of #{filename}.", origin_path)
        end
      end
    end
  end
end
