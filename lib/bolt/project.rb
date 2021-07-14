# frozen_string_literal: true

require 'pathname'
require 'bolt/config'
require 'bolt/validator'
require 'bolt/pal'
require 'bolt/module'

module Bolt
  class Project
    BOLTDIR_NAME = 'Boltdir'
    CONFIG_NAME  = 'bolt-project.yaml'

    attr_reader :path, :data, :inventory_file, :hiera_config,
                :puppetfile, :rerunfile, :type, :resource_types, :project_file,
                :downloads, :plans_path, :modulepath, :managed_moduledir,
                :backup_dir, :plugin_cache_file, :plan_cache_file, :task_cache_file

    def self.default_project
      create_project(File.expand_path(File.join('~', '.puppetlabs', 'bolt')), 'user')
    # If homedir isn't defined use the system config path
    rescue ArgumentError
      create_project(Bolt::Config.system_path, 'system')
    end

    # Search recursively up the directory hierarchy for the Project. Look for a
    # directory called Boltdir or a file called bolt-project.yaml (for a control
    # repo type Project). Otherwise, repeat the check on each directory up the
    # hierarchy, falling back to the default if we reach the root.
    def self.find_boltdir(dir)
      dir = Pathname.new(dir)

      if (dir + BOLTDIR_NAME).directory?
        create_project(dir + BOLTDIR_NAME, 'embedded')
      elsif (dir + CONFIG_NAME).file?
        create_project(dir, 'local')
      elsif dir.root?
        default_project
      else
        Bolt::Logger.debug(
          "Did not detect Boltdir or bolt-project.yaml at '#{dir}'. This directory won't be loaded as a project."
        )
        find_boltdir(dir.parent)
      end
    end

    def self.create_project(path, type = 'option')
      fullpath = Pathname.new(path).expand_path

      if type == 'user'
        begin
          # This is already expanded if the type is user
          FileUtils.mkdir_p(path)
        rescue StandardError
          Bolt::Logger.warn(
            "non_writeable_project",
            "Could not create default project at #{path}. Continuing without a writeable project. "\
            "Log and rerun files will not be written."
          )
        end
      end

      if type == 'option' && !File.directory?(path)
        raise Bolt::Error.new("Could not find project at #{path}", "bolt/project-error")
      end

      if !Bolt::Util.windows? && type != 'environment' && fullpath.world_writable?
        raise Bolt::Error.new(
          "Project directory '#{fullpath}' is world-writable which poses a security risk. Set "\
          "BOLT_PROJECT='#{fullpath}' to force the use of this project directory.",
          "bolt/world-writable-error"
        )
      end

      project_file = File.join(fullpath, CONFIG_NAME)
      data         = Bolt::Util.read_optional_yaml_hash(File.expand_path(project_file), 'project')
      default      = type =~ /user|system/ ? 'default ' : ''

      if File.exist?(File.expand_path(project_file))
        Bolt::Logger.info("Loaded #{default}project from '#{fullpath}'")
      end

      Bolt::Validator.new.tap do |validator|
        validator.validate(data, schema, project_file)
        validator.warnings.each { |warning| Bolt::Logger.warn(warning[:id], warning[:msg]) }
        validator.deprecations.each { |dep| Bolt::Logger.deprecate(dep[:id], dep[:msg]) }
      end

      new(data, path, type)
    end

    # Builds the schema for bolt-project.yaml used by the validator.
    #
    def self.schema
      {
        type:        Hash,
        properties:  Bolt::Config::PROJECT_OPTIONS.map { |opt| [opt, _ref: opt] }.to_h,
        definitions: Bolt::Config::OPTIONS
      }
    end

    def initialize(data, path, type = 'option')
      @type              = type
      @path              = Pathname.new(path).expand_path
      @project_file      = @path + CONFIG_NAME
      @inventory_file    = @path + 'inventory.yaml'
      @hiera_config      = @path + 'hiera.yaml'
      @puppetfile        = @path + 'Puppetfile'
      @rerunfile         = @path + '.rerun.json'
      @resource_types    = @path + '.resource_types'
      @downloads         = @path + 'downloads'
      @plans_path        = @path + 'plans'
      @managed_moduledir = @path + '.modules'
      @backup_dir        = @path + '.bolt-bak'
      @plugin_cache_file = @path + '.plugin_cache.json'
      @plan_cache_file   = @path + '.plan_cache.json'
      @task_cache_file   = @path + '.task_cache.json'
      @modulepath        = [(@path + 'modules').to_s]

      if (tc = Bolt::Config::INVENTORY_OPTIONS.keys & data.keys).any?
        Bolt::Logger.warn(
          "project_transport_config",
          "Transport configuration isn't supported in bolt-project.yaml. Ignoring keys #{tc}."
        )
      end

      @data = data.slice(*Bolt::Config::PROJECT_OPTIONS)

      validate if project_file?
    end

    def to_s
      @path.to_s
    end

    # This API is used to prepend the project as a module to Puppet's internal
    # module_references list. CHANGE AT YOUR OWN RISK
    def to_h
      { path: @path.to_s,
        name: name,
        load_as_module?: load_as_module? }
    end

    def eql?(other)
      path == other.path
    end
    alias == eql?

    def project_file?
      @project_file.file?
    end

    def load_as_module?
      !name.nil?
    end

    def name
      @data['name']
    end

    def tasks
      @data['tasks']
    end

    def plans
      @data['plans']
    end

    def plugin_cache
      @data['plugin-cache']
    end

    def module_install
      @data['module-install']
    end

    def disable_warnings
      @data['disable-warnings'] || []
    end

    def modules
      mod_data = @data['modules'] || []
      @modules ||= mod_data.map do |mod|
        if mod.is_a?(String)
          { 'name' => mod }
        else
          mod
        end
      end
    end

    def validate
      if name
        if name !~ Bolt::Module::MODULE_NAME_REGEX
          raise Bolt::ValidationError, <<~ERROR_STRING
          Invalid project name '#{name}' in bolt-project.yaml; project name must begin with a lowercase letter
          and can include lowercase letters, numbers, and underscores.
          ERROR_STRING
        elsif Dir.children(Bolt::Config::Modulepath::BOLTLIB_PATH).include?(name)
          raise Bolt::ValidationError, "The project '#{name}' will not be loaded. The project name conflicts "\
            "with a built-in Bolt module of the same name."
        end
      elsif name.nil? &&
            (File.directory?(plans_path) ||
            File.directory?(@path + 'tasks') ||
            File.directory?(@path + 'files'))
        message = "No project name is specified in bolt-project.yaml. Project-level content will not be available."

        Bolt::Logger.warn("missing_project_name", message)
      end
    end
  end
end
