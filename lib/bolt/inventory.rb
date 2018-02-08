require 'set'
require 'bolt/util'
require 'bolt/target'
require 'bolt/inventory/group'

module Bolt
  class Inventory
    class ValidationError < Bolt::Error
      attr_accessor :path
      def initialize(message, offending_group)
        super(msg, 'bolt.inventory/validation-error')
        @_message = message
        @path = offending_group ? [offending_group] : []
      end

      def details
        { 'path' => path }
      end

      def add_parent(parent_group)
        @path << parent_group
      end

      def message
        "#{@_message} for group at #{path}"
      end
    end

    def self.default_paths
      [File.expand_path(File.join('~', '.puppetlabs', 'bolt', 'inventory.yaml'))]
    end

    def self.from_config(config)
      data = Bolt::Util.read_config_file(config[:inventoryfile], default_paths, 'inventory')

      inventory = new(data, config)
      inventory.validate
      inventory
    end

    def initialize(data, config = nil)
      @logger = Logging.logger[self]
      # Config is saved to add config options to targets
      @config = config || {}
      @data = data ||= {}
      @groups = Group.new(data.merge('name' => 'all'))
    end

    def validate
      @groups.validate
    end

    def get_targets(targets)
      targets = expand_targets(targets)
      targets = if targets.is_a? Array
                  targets.flatten.uniq(&:name)
                else
                  [targets]
                end
      targets.map { |t| update_target(t) }
    end

    # Should this be a public method?
    def config_for(node_name)
      data = @groups.data_for(node_name)
      if data
        Bolt::Util.symbolize_keys(data['config'])
      end
    end

    #### PRIVATE ####
    #
    # For debugging only now
    def groups_in(node_name)
      @groups.data_for(node_name)['groups'] || {}
    end

    # Pass a target to get_targets for a public version of this
    # Should this reconfigure configured targets?
    def update_target(target)
      inv_conf = config_for(target.host)
      unless inv_conf
        @logger.debug("Did not find #{target.host} in inventory")
        inv_conf = {}
      end

      conf = Bolt::Util.deep_merge(@config.transport_conf, inv_conf)
      target.update_conf(conf)
    end

    def expand_targets(targets)
      if targets.is_a? Bolt::Target
        targets
      elsif targets.is_a? Array
        targets.map { |tish| expand_targets(tish) }
      elsif targets.is_a? String
        # Expand a comma-separated list
        targets.split(/[[:space:],]+/).reject(&:empty?).map { |t| Bolt::Target.new(t) }
      end
    end
  end
end
