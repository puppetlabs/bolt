# frozen_string_literal: true

require 'bolt/inventory/group2'

module Bolt
  class Inventory
    class Inventory2
      # This uses "targets" in the message instead of "nodes"
      class WildcardError < Bolt::Error
        def initialize(target)
          super("Found 0 targets matching wildcard pattern #{target}", 'bolt.inventory/wildcard-error')
        end
      end

      def initialize(data, config = nil, plugins: nil, target_vars: {}, target_facts: {}, target_features: {})
        @logger = Logging.logger[self]
        # Config is saved to add config options to targets
        @config = config || Bolt::Config.default
        @data = data || {}
        @groups = Group2.new(@data.merge('name' => 'all'), plugins)
        @group_lookup = {}
        @target_vars = target_vars
        @target_facts = target_facts
        @target_features = target_features
        @groups.lookup_targets(plugins)
        @groups.resolve_aliases(@groups.target_aliases, @groups.target_names)
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

      def target_names
        @groups.target_names
      end
      # alias for analytics
      alias node_names target_names

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
              raise ValidationError.new("Group #{target.name} conflicts with target of the same name", target.name)
            end
            add_target(@groups, target, desired_group)
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
      def groups_in(target_name)
        @groups.data_for(target_name)['groups'] || {}
      end
      private :groups_in

      # Look for _plugins
      def config_plugin(data)
        Bolt::Util.walk_vals(data) do |val|
          if val.is_a?(Concurrent::Delay)
            val.value
          else
            val
          end
        end
      end
      private :config_plugin

      # Pass a target to get_targets for a public version of this
      # Should this reconfigure configured targets?
      def update_target(target)
        data = @groups.data_for(target.name)
        data ||= {}

        unless data['config']
          @logger.debug("Did not find config for #{target.name} in inventory")
          data['config'] = {}
        end

        data = Bolt::Inventory.localhost_defaults(data) if target.name == 'localhost'
        # These should only get set from the inventory if they have not yet
        # been instantiated
        set_vars_from_hash(target.name, data['vars']) unless @target_vars[target.name]
        set_facts(target.name, data['facts']) unless @target_facts[target.name]
        data['features']&.each { |feature| set_feature(target, feature) } unless @target_features[target.name]
        data['config'] = config_plugin(data['config'])

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
      # Else match against targets in inventory by name or alias.
      # If a wildcard string, error if no matches are found.
      # Else fall back to [target] if no matches are found.
      def resolve_name(target)
        if (group = @group_lookup[target])
          group.target_names
        else
          # Try to wildcard match targets in inventory
          # Ignore case because hostnames are generally case-insensitive
          regexp = Regexp.new("^#{Regexp.escape(target).gsub('\*', '.*?')}$", Regexp::IGNORECASE)

          targets = @groups.target_names.select { |targ| targ =~ regexp }
          targets += @groups.target_aliases.select { |target_alias, _target| target_alias =~ regexp }.values

          if targets.empty?
            raise(WildcardError, target) if target.include?('*')
            [target]
          else
            targets
          end
        end
      end
      private :resolve_name

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

      def add_target(current_group, target, desired_group, track = { 'all' => nil })
        if current_group.name == desired_group
          # Group to add to is found
          t_name = target.name
          # Add target to targets hash
          target_hash = { 'name' => t_name }.merge(target.options)
          target_hash['uri'] = target.uri if target.uri
          current_group.targets[t_name] = target_hash

          # Inherit facts, vars, and features from hierarchy
          current_group_data = { facts: current_group.facts,
                                 vars: current_group.vars,
                                 features: current_group.features }
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
          add_target(child_group, target, desired_group, track)
        end
      end
      private :add_target

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

      def create_target(target_name)
        data = @groups.data_for(target_name) || {}
        name_opt = {}
        name_opt['name'] = data['name'] if data['name']

        # If there is no name then this target was only referred to as a string.
        uri = data['uri']
        uri ||= target_name unless data['name']

        Target.new(uri, name_opt)
      end
    end
  end
end
