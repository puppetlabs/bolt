# frozen_string_literal: true

require 'pathname'
require 'bolt/pal'

module Bolt
  class Project
    BOLTDIR_NAME = 'Boltdir'
    PROJECT_SETTINGS = {
      "name"  => "The name of the project",
      "plans" => "An array of plan names to whitelist. Whitelisted plans are included in `bolt plan show` output",
      "tasks" => "An array of task names to whitelist. Whitelisted plans are included in `bolt task show` output"
    }.freeze

    attr_reader :path, :config_file, :inventory_file, :modulepath, :hiera_config,
                :puppetfile, :rerunfile, :type, :resource_types

    def self.default_project
      Project.new(File.join('~', '.puppetlabs', 'bolt'), 'user')
    end

    # Search recursively up the directory hierarchy for the Project. Look for a
    # directory called Boltdir or a file called bolt.yaml (for a control repo
    # type Project). Otherwise, repeat the check on each directory up the
    # hierarchy, falling back to the default if we reach the root.
    def self.find_boltdir(dir)
      dir = Pathname.new(dir)
      # allows for any case of Boltdir, BoltDir, boltdir, etc
      # note: we're sorting the directories here so that we consistently pick the
      #       same Boltdir between runs, and we always choose the lexicographical "less"
      #       Boltdir name rather than whatever the first name we run into as returned by
      #       the filesystem
      boltdirs = dir.children.sort.select { |c| c.directory? && c.basename.to_s.casecmp?(BOLTDIR_NAME) }
      if !boltdirs.empty?
        new(boltdirs.first, 'embedded')
      elsif (dir + 'bolt.yaml').file? || (dir + 'bolt-project.yaml').file?
        new(dir, 'local')
      elsif dir.root?
        default_project
      else
        find_boltdir(dir.parent)
      end
    end

    def initialize(path, type = 'option')
      @path = Pathname.new(path).expand_path
      @config_file = @path + 'bolt.yaml'
      @inventory_file = @path + 'inventory.yaml'
      @modulepath = [(@path + 'modules').to_s, (@path + 'site-modules').to_s, (@path + 'site').to_s]
      @hiera_config = @path + 'hiera.yaml'
      @puppetfile = @path + 'Puppetfile'
      @rerunfile = @path + '.rerun.json'
      @resource_types = @path + '.resource_types'
      @type = type

      @project_file = @path + 'bolt-project.yaml'
      @data = Bolt::Util.read_optional_yaml_hash(File.expand_path(@project_file), 'project') || {}
      validate if load_as_module?
    end

    def to_s
      @path.to_s
    end

    # This API is used to prepend the project as a module to Puppet's internal
    # module_references list. CHANGE AT YOUR OWN RISK
    def to_h
      { path: @path, name: name }
    end

    def eql?(other)
      path == other.path
    end
    alias == eql?

    def load_as_module?
      @project_file.file?
    end

    def name
      # If the project is in mymod/Boltdir/bolt-project.yaml, use mymod as the project name
      dirname = @path.basename.to_s.casecmp?(BOLTDIR_NAME) ? @path.parent.basename.to_s : @path.basename.to_s
      pname = @data['name'] || dirname
      pname.include?('-') ? pname.split('-', 2)[1] : pname
    end

    def tasks
      @data['tasks']
    end

    def plans
      @data['plans']
    end

    def project_directory_name?(name)
      # it must match an installed project name according to forge validator
      name =~ /^[a-z][a-z0-9_]*$/
    end

    def project_namespaced_name?(name)
      # it must match the full project name according to forge validator
      name =~ /^[a-zA-Z0-9]+[-][a-z][a-z0-9_]*$/
    end

    def validate
      n = @data['name']
      if n && !project_directory_name?(n) && !project_namespaced_name?(n)
        raise Bolt::ValidationError, <<~ERROR_STRING
        Invalid project name '#{n}' in bolt-project.yaml; project names must match either:
        An installed project name (ex. projectname) matching the expression /^[a-z][a-z0-9_]*$/ -or-
        A namespaced project name (ex. author-projectname) matching the expression /^[a-zA-Z0-9]+[-][a-z][a-z0-9_]*$/
        ERROR_STRING
      elsif !project_directory_name?(name) && !project_namespaced_name?(name)
        raise Bolt::ValidationError, <<~ERROR_STRING
        Invalid project name '#{name}'; project names must match either:
        A project name (ex. projectname) matching the expression /^[a-z][a-z0-9_]*$/ -or-
        A namespaced project name (ex. author-projectname) matching the expression /^[a-zA-Z0-9]+[-][a-z][a-z0-9_]*$/

        Configure project name in <project_dir>/bolt-project.yaml
        ERROR_STRING
      # If the project name is the same as one of the built-in modules raise a warning
      elsif Dir.children(Bolt::PAL::BOLTLIB_PATH).include?(name)
        raise Bolt::ValidationError, "The project '#{name}' will not be loaded. The project name conflicts "\
          "with a built-in Bolt module of the same name."
      end

      %w[tasks plans].each do |conf|
        unless @data.fetch(conf, []).is_a?(Array)
          raise Bolt::ValidationError, "'#{conf}' in bolt-project.yaml must be an array"
        end
      end
    end

    def check_deprecated_file
      if (@path + 'project.yaml').file?
        logger = Logging.logger[self]
        logger.warn "Project configuration file 'project.yaml' is deprecated; use 'bolt-project.yaml' instead."
      end
    end
  end
end
