# frozen_string_literal: true

require 'set'
require 'bolt/config'
require 'bolt/inventory/group'
require 'bolt/inventory/inventory2'
require 'bolt/target'
require 'bolt/util'
require 'yaml'

module Bolt
  class Inventory
    ENVIRONMENT_VAR = 'BOLT_INVENTORY'

    class ValidationError < Bolt::Error
      attr_accessor :path
      def initialize(message, offending_group)
        super(message, 'bolt.inventory/validation-error')
        @_message = message
        @path = [offending_group].compact
      end

      def details
        { 'path' => path }
      end

      def add_parent(parent_group)
        @path << parent_group
      end

      def message
        if path.empty?
          @_message
        else
          "#{@_message} for group at #{path}"
        end
      end
    end

    class WildcardError < Bolt::Error
      def initialize(target)
        super("Found 0 nodes matching wildcard pattern #{target}", 'bolt.inventory/wildcard-error')
      end
    end

    def self.from_config(config, plugins = nil)
      if ENV.include?(ENVIRONMENT_VAR)
        begin
          data = YAML.safe_load(ENV[ENVIRONMENT_VAR])
          raise Bolt::ParseError, "Could not parse inventory from $#{ENVIRONMENT_VAR}" unless data.is_a?(Hash)
        rescue Psych::Exception
          raise Bolt::ParseError, "Could not parse inventory from $#{ENVIRONMENT_VAR}"
        end
      else
        data = Bolt::Util.read_config_file(config.inventoryfile, config.default_inventoryfile, 'inventory')
      end

      inventory = create_version(data, config, plugins)
      inventory.validate
      inventory
    end

    def self.create_version(data, config, plugins)
      version = (data || {}).delete('version') { 1 }
      case version
      when 1
        new(data, config, plugins: plugins)
      when 2
        Bolt::Inventory::Inventory2.new(data, config, plugins: plugins)
      else
        raise ValidationError.new("Unsupported version #{version} specified in inventory", nil)
      end
    end

    attr_reader :plugins, :config

    def initialize(data, config = nil, plugins: nil, target_vars: {},
                   target_facts: {}, target_features: {}, target_plugin_hooks: {})
      @logger = Logging.logger[self]
      # Config is saved to add config options to targets
      @config = config || Bolt::Config.default
      @data = data ||= {}
      @groups = Group.new(data.merge('name' => 'all'))
      @group_lookup = {}
      @target_vars = target_vars
      @target_facts = target_facts
      @target_features = target_features
      @plugins = plugins
      @target_plugin_hooks = target_plugin_hooks

      @groups.resolve_aliases(@groups.node_aliases)
      collect_groups
    end

    def validate
      @groups.validate
    end

    def version
      1
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

    def plugin_hooks(target)
      @target_plugin_hooks[target.name] || {}
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

    def set_var(target, var_hash)
      set_vars_from_hash(target.name, var_hash)
    end

    def vars(target)
      @target_vars[target.name] || {}
    end

    def add_facts(target, new_facts = {})
      @logger.warn("No facts to add") if new_facts.empty?
      facts = set_facts(target.name, new_facts)
      # rubocop:disable Style/GlobalVars
      $future ? target : facts
      # rubocop:enable Style/GlobalVars
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

    def target_alias(target)
      @groups.node_aliases.each_with_object([]) do |(alia, name), acc|
        if target.name == name
          acc << alia
        end
      end.uniq
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

    # TODO: Possibly refactor this once inventory v2 is more stable
    def self.localhost_defaults(data)
      defaults = {
        'config' => {
          'transport' => 'local',
          'local' => { 'interpreters' => { '.rb' => RbConfig.ruby } }
        },
        'features' => ['puppet-agent']
      }
      data = Bolt::Util.deep_merge(defaults, data)
      # If features is an empty array deep_merge won't add the puppet-agent
      data['features'] += ['puppet-agent'] if data['features'].empty?
      data
    end

    # Pass a target to get_targets for a public version of this
    # Should this reconfigure configured targets?
    def update_target(target)
      data = @groups.data_for(target.name)
      data ||= {}

      unless data['config']
        @logger.debug("Did not find config for #{target.name} in inventory")
        data['config'] = {}
      end

      data = self.class.localhost_defaults(data) if target.name == 'localhost'
      # These should only get set from the inventory if they have not yet
      # been instantiated
      set_vars_from_hash(target.name, data['vars']) unless @target_vars[target.name]
      set_facts(target.name, data['facts']) unless @target_facts[target.name]
      data['features']&.each { |feature| set_feature(target, feature) } unless @target_features[target.name]
      unless @target_plugin_hooks[target.name]
        set_plugin_hooks(target.name, (@plugins&.plugin_hooks || {}).merge(data['plugin_hooks'] || {}))
      end

      # Use Config object to ensure config section is treated consistently with config file
      conf = @config.deep_clone
      conf.update_from_inventory(data['config'])
      conf.validate

      target.update_conf(conf.transport_conf)

      unless target.transport.nil? || Bolt::TRANSPORTS.include?(target.transport.to_sym)
        raise Bolt::UnknownTransportError.new(target.transport, target.uri)
      end

      target
    end
    private :update_target

    # If target is a group name, expand it to the members of that group.
    # Else match against nodes in inventory by name or alias.
    # If a wildcard string, error if no matches are found.
    # Else fall back to [target] if no matches are found.
    def resolve_name(target)
      if (group = @group_lookup[target])
        group.node_names
      else
        # Try to wildcard match nodes in inventory
        # Ignore case because hostnames are generally case-insensitive
        regexp = Regexp.new("^#{Regexp.escape(target).gsub('\*', '.*?')}$", Regexp::IGNORECASE)

        nodes = @groups.node_names.select { |node| node =~ regexp }
        nodes += @groups.node_aliases.select { |target_alias, _node| target_alias =~ regexp }.values

        if nodes.empty?
          raise(WildcardError, target) if target.include?('*')
          [target]
        else
          nodes
        end
      end
    end
    private :resolve_name

    def create_target(data)
      Bolt::Target.new(data)
    end
    private :create_target

    def expand_targets(targets)
      if targets.is_a? Bolt::Target
        targets.inventory = self
        targets
      elsif targets.is_a? Array
        targets.map { |tish| expand_targets(tish) }
      elsif targets.is_a? String
        # Expand a comma-separated list
        targets.split(/[[:space:],]+/).reject(&:empty?).map do |name|
          ts = resolve_name(name)
          ts.map do |t|
            target = create_target(t)
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

    def set_plugin_hooks(tname, hash)
      if hash
        @target_plugin_hooks[tname] ||= {}
        @target_plugin_hooks[tname].merge!(hash)
      end
    end
    private :set_plugin_hooks

    def add_node(current_group, target, desired_group, track = { 'all' => nil })
      if current_group.name == desired_group
        # Group to add to is found
        t_name = target.name
        # Add target to nodes hash
        current_group.nodes[t_name] = { 'name' => t_name }.merge(target.options)
        # Inherit facts, vars, and features from hierarchy
        current_group_data = { facts: current_group.facts,
                               vars: current_group.vars,
                               features: current_group.features,
                               plugin_hooks: current_group.plugin_hooks }
        data = inherit_data(track, current_group.name, current_group_data)
        set_facts(t_name, @target_facts[t_name] ? data[:facts].merge(@target_facts[t_name]) : data[:facts])
        set_vars_from_hash(t_name, @target_vars[t_name] ? data[:vars].merge(@target_vars[t_name]) : data[:vars])
        data[:features].each do |feature|
          set_feature(target, feature)
        end
        hook_data = @config.plugin_hooks.merge(data[:plugin_hooks])
        hash = if @target_plugin_hooks[t_name]
                 hook_data.merge(@target_plugin_hooks[t_name])
               else
                 hook_data
               end
        set_plugin_hooks(t_name, hash)
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
        data[:plugin_hooks] = track[name].plugin_hooks.merge(data[:plugin_hooks])
        inherit_data(track, track[name].name, data)
      end
      data
    end
    private :inherit_data
  end
end
