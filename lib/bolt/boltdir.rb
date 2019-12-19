# frozen_string_literal: true

require 'pathname'

module Bolt
  class Boltdir
    BOLTDIR_NAME = 'Boltdir'

    attr_reader :path, :config_file, :inventory_file, :modulepath, :hiera_config,
                :puppetfile, :rerunfile, :type, :resource_types

    def self.default_boltdir
      Boltdir.new(File.join('~', '.puppetlabs', 'bolt'), 'user')
    end

    # Search recursively up the directory hierarchy for the Boltdir. Look for a
    # directory called Boltdir or a file called bolt.yaml or bolt.yml (for a
    # control repo type Boltdir). Otherwise, repeat the check on each directory
    # up the hierarchy, falling back to the default if we reach the root.
    def self.find_boltdir(dir)
      dir = Pathname.new(dir)
      if (dir + BOLTDIR_NAME).directory?
        new(dir + BOLTDIR_NAME, 'embedded')
      elsif (dir + 'bolt.yaml').file?
        new(dir, 'local')
      elsif (dir + 'bolt.yml').file?
        new(dir, 'local')
      elsif dir.root?
        default_boltdir
      else
        find_boltdir(dir.parent)
      end
    end

    def initialize(path, type = 'option')
      @path = Pathname.new(path).expand_path
      @config_file = if (@path + 'bolt.yaml').file? || !(@path + 'bolt.yml').file?
                       @path + 'bolt.yaml'
                     else
                       @path + 'bolt.yml'
                     end
      @inventory_file = if (@path + 'inventory.yaml').file? || !(@path + 'inventory.yml').file?
                          @path + 'inventory.yaml'
                        else
                          @path + 'inventory.yml'
                        end
      @modulepath = [(@path + 'modules').to_s, (@path + 'site-modules').to_s, (@path + 'site').to_s]
      @hiera_config = @path + 'hiera.yaml'
      @puppetfile = @path + 'Puppetfile'
      @rerunfile = @path + '.rerun.json'
      @resource_types = @path + '.resource_types'
      @type = type
    end

    def to_s
      @path.to_s
    end

    def eql?(other)
      path == other.path
    end
    alias == eql?
  end
end
