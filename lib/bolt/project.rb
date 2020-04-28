# frozen_string_literal: true

require 'pathname'

module Bolt
  class Project
    BOLTDIR_NAME = 'Boltdir'
    PROJECT_SETTINGS = {
      "plans" => "An array of plan names that can be included in `bolt plan show` output",
      "tasks" => "An array of task names that can be included in `bolt task show` output"
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
      if (dir + BOLTDIR_NAME).directory?
        new(dir + BOLTDIR_NAME, 'embedded')
      elsif (dir + 'bolt.yaml').file?
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

      project_file = @path + 'project.yaml'
      @data = Bolt::Util.read_optional_yaml_hash(File.expand_path(project_file), 'project') || {}
      validate
    end

    def to_s
      @path.to_s
    end

    def eql?(other)
      path == other.path
    end
    alias == eql?

    def tasks
      @data['tasks']
    end

    def plans
      @data['plans']
    end

    def validate
      %w[tasks plans].each do |conf|
        unless @data.fetch(conf, []).is_a?(Array)
          raise Bolt::ValidationError, "'#{conf}' in project.yaml must be an array"
        end
      end
    end
  end
end
