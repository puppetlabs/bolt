# frozen_string_literal: true

require 'set'
require 'bolt/config'
require 'bolt/inventory/group'
require 'bolt/target'
require 'bolt/util'

module Bolt
  class Inventory
    ENVIRONMENT_VAR = 'BOLT_INVENTORY'

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

    class WildcardError < Bolt::Error
      def initialize(target)
        super("Found 0 nodes matching wildcard pattern #{target}", 'bolt.inventory/wildcard-error')
      end
    end

    def self.from_config(config)
      if ENV.include?(ENVIRONMENT_VAR)
        begin
          data = YAML.safe_load(ENV[ENVIRONMENT_VAR])
        rescue Psych::Exception
          raise Bolt::ParseError, "Could not parse inventory from $#{ENVIRONMENT_VAR}"
        end
      else
        data = Bolt::Util.read_config_file(config.inventoryfile, config.default_inventoryfile, 'inventory')
      end

      inventory = new(data, config)
      inventory.validate
      inventory
    end

    def initialize(data, config = nil, target_vars: {}, target_facts: {}, target_features: {})
      @logger = Logging.logger[self]
      # Config is saved to add config options to targets
      @config = config || Bolt::Config.default
      @data = data ||= {}
      @groups = Group.new(data.merge('name' => 'all'))
      @group_lookup = {}
      @target_vars = target_vars
      @target_facts = target_facts
      @target_features = target_features
      collect_groups
    end

    def validate
      @groups.validate
    end

    def collect_groups
      # Provide a lookup map for finding a group by name
      @group_lookup = @groups.collect_groups
    end

    def group_names
      @group_lookup.keys
    end

    def node_names
      @groups.node_names
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

    def add_to_group(targets, desired_group)
      if group_names.include?(desired_group)
        targets.each do |target|
          if group_names.include?(target.name)
            raise ValidationError.new("Group #{target.name} conflicts with node of the same name", target.name)
          end
          add_node(@groups, target, desired_group)
        end
      else
        raise ValidationError.new("Group #{desired_group} does not exist in inventory", nil)
      end
    end

    def set_var(target, key, value)
      data = { key => value }
      set_vars_from_hash(target.name, data)
    end

    def vars(target)
      @target_vars[target.name] || {}
    end

    def add_facts(target, new_facts = {})
      @logger.warn("No facts to add") if new_facts.empty?
      set_facts(target.name, new_facts)
    end

    def facts(target)
      @target_facts[target.name] || {}
    end

    def set_feature(target, feature, value = true)
      @target_features[target.name] ||= Set.new
      if value
        @target_features[target.name] << feature
      else
        @target_features[target.name].delete(feature)
      end
    end

    def features(target)
      @target_features[target.name] || Set.new
    end

    def data_hash
      {
        data: @data,
        target_hash: {
          target_vars: @target_vars,
          target_facts: @target_facts,
          target_features: @target_features
        },
        config: @config.transport_data_get
      }
    end

    #### PRIVATE ####
    #
    # For debugging only now
    def groups_in(node_name)
      @groups.data_for(node_name)['groups'] || {}
    end
    private :groups_in

    # Pass a target to get_targets for a public version of this
    # Should this reconfigure configured targets?
    def update_target(target)
      data = @groups.data_for(target.name)

      unless data
        data = {}
        unless Bolt::Util.windows?
          data['config'] = { 'transport' => 'local' } if target.name == 'localhost'
        end
      end

      unless data['config']
        @logger.debug("Did not find config for #{target.name} in inventory")
        data['config'] = {}
      end

      # These should only get set from the inventory if they have not yet
      # been instantiated
      set_vars_from_hash(target.name, data['vars']) unless @target_vars[target.name]
      set_facts(target.name, data['facts']) unless @target_facts[target.name]
      data['features']&.each { |feature| set_feature(target, feature) } unless @target_features[target.name]

      # Use Config object to ensure config section is treated consistently with config file
      conf = @config.deep_clone
      conf.update_from_inventory(data['config'])
      conf.validate

      unless target.protocol.nil? || Bolt::TRANSPORTS.include?(target.protocol.to_sym)
        raise Bolt::UnknownTransportError.new(target.protocol, target.uri)
      end

      target.update_conf(conf.transport_conf)
    end
    private :update_target

    # If target is a group name, expand it to the members of that group.
    # If a wildcard string, match against nodes in inventory (or error if none found).
    # Else return [target].
    def resolve_name(target)
      if (group = @group_lookup[target])
        group.node_names
      elsif target.include?('*')
        # Try to wildcard match nodes in inventory
        # Ignore case because hostnames are generally case-insensitive
        regexp = Regexp.new("^#{Regexp.escape(target).gsub('\*', '.*?')}$", Regexp::IGNORECASE)

        nodes = []
        @groups.node_names.each do |node|
          nodes << node if node =~ regexp
        end

        raise(WildcardError, target) if nodes.empty?
        nodes
      else
        [target]
      end
    end
    private :resolve_name

    def expand_targets(targets)
      if targets.is_a? Bolt::Target
        targets
      elsif targets.is_a? Array
        targets.map { |tish| expand_targets(tish) }
      elsif targets.is_a? String
        # Expand a comma-separated list
        targets.split(/[[:space:],]+/).reject(&:empty?).map do |name|
          ts = resolve_name(name)
          ts.map do |t|
            target = Target.new(t)
            target.inventory = self
            target
          end
        end
      end
    end
    private :expand_targets

    def set_vars_from_hash(tname, data)
      if data
        # Instantiate empty vars hash in case no vars are defined
        @target_vars[tname] ||= {}
        # Assign target new merged vars hash
        # This is essentially a copy-on-write to maintain the immutability of @target_vars
        @target_vars[tname] = @target_vars[tname].merge(data).freeze
      end
    end
    private :set_vars_from_hash

    def set_facts(tname, hash)
      if hash
        @target_facts[tname] ||= {}
        @target_facts[tname] = Bolt::Util.deep_merge(@target_facts[tname], hash).freeze
      end
    end
    private :set_facts

    def add_node(current_group, target, desired_group, track = { 'all' => nil })
      if current_group.name == desired_group
        # Group to add to is found
        t_name = target.name
        # Add target to nodes hash
        current_group.nodes[t_name] = { 'name' => t_name }.merge(target.options)
        # Inherit facts, vars, and features from hierarchy
        current_group_data = { facts: current_group.facts, vars: current_group.vars, features: current_group.features }
        data = inherit_data(track, current_group.name, current_group_data)
        set_facts(t_name, @target_facts[t_name] ? data[:facts].merge(@target_facts[t_name]) : data[:facts])
        set_vars_from_hash(t_name, @target_vars[t_name] ? data[:vars].merge(@target_vars[t_name]) : data[:vars])
        data[:features].each do |feature|
          set_feature(target, feature)
        end
        return true
      end
      # Recurse on children Groups if not desired_group
      current_group.groups.each do |child_group|
        track[child_group.name] = current_group
        add_node(child_group, target, desired_group, track)
      end
    end
    private :add_node

    def inherit_data(track, name, data)
      unless track[name].nil?
        data[:facts] = track[name].facts.merge(data[:facts])
        data[:vars] = track[name].vars.merge(data[:vars])
        data[:features].concat(track[name].features)
        inherit_data(track, track[name].name, data)
      end
      data
    end
    private :inherit_data
  end
end
