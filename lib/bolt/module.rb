# frozen_string_literal: true

# Is this Bolt::Pobs::Module?
module Bolt
  class Module
    MODULE_NAME_REGEX = /\A[a-z][a-z0-9_]*\z/.freeze

    def self.discover(modulepath)
      modulepath.each_with_object({}) do |path, mods|
        next unless File.exist?(path) && File.directory?(path)
        (Dir.entries(path) - %w[. ..])
          .map { |dir| File.join(path, dir) }
          .select { |dir| File.directory?(dir) }
          .each do |dir|
          module_name = File.basename(dir)
          if module_name =~ MODULE_NAME_REGEX
            # Puppet will load some objects from shadowed modules but this won't
            mods[module_name] ||= Bolt::Module.new(module_name, dir)
          end
        end
      end
    end

    attr_reader :name, :path

    def initialize(name, path)
      @name = name
      @path = path
    end

    def plugin_data_file
      File.join(path, 'bolt_plugin.json')
    end

    def plugin?
      File.exist?(plugin_data_file)
    end
  end
end
