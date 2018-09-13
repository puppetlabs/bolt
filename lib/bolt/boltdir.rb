# frozen_string_literal: true

require 'pathname'

module Bolt
  class Boltdir
    BOLTDIR_NAME = 'Boltdir'

    attr_reader :path, :config_file, :inventory_file, :modulepath, :hiera_config, :puppetfile

    def self.default_boltdir
      Boltdir.new(File.join('~', '.puppetlabs', 'bolt'))
    end

    def self.find_boltdir(dir)
      local_boltdir = Pathname.new(dir).ascend do |path|
        boltdir = path + BOLTDIR_NAME
        break new(boltdir) if boltdir.directory?
      end

      local_boltdir || default_boltdir
    end

    def initialize(path)
      @path = Pathname.new(path).expand_path
      @config_file = @path + 'bolt.yaml'
      @inventory_file = @path + 'inventory.yaml'
      @modulepath = [(@path + 'modules').to_s, (@path + 'site').to_s]
      @hiera_config = @path + 'hiera.yaml'
      @puppetfile = @path + 'Puppetfile'
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
