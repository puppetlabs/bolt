# frozen_string_literal: true

# Is this Bolt::Pobs::Module?
module Bolt
  class Module
    CONTENT_NAME_REGEX = /\A[a-z][a-z0-9_]*(::[a-z][a-z0-9_]*)*\z/.freeze
    MODULE_NAME_REGEX  = /\A[a-z][a-z0-9_]*\z/.freeze

    def self.discover(modulepath, project)
      mods = {}

      if project.load_as_module?
        mods[project.name] = Bolt::Module.new(project.name, project.path.to_s)
      end

      modulepath.each do |path|
        next unless File.exist?(path) && File.directory?(path)
        Dir.children(path)
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

      mods
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
      if File.exist?(File.join(path, 'bolt-plugin.json'))
        msg = "Found bolt-plugin.json in module #{name} at #{path}. Bolt looks for " \
              "bolt_plugin.json to determine if the module contains plugins. " \
              "Rename the file for Bolt to recognize it."
        Bolt::Logger.warn_once('plugin_file_name', msg)
      end
      File.exist?(plugin_data_file)
    end
  end
end
