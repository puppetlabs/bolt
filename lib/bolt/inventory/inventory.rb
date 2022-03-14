# frozen_string_literal: true

require_relative '../../bolt/inventory/group'
require_relative '../../bolt/inventory/target'

module Bolt
  class Inventory
    class Inventory
      attr_reader :plugins, :source, :targets, :transport

      class WildcardError < Bolt::Error
        def initialize(target)
          super("Found 0 targets matching wildcard pattern #{target}", 'bolt.inventory/wildcard-error')
        end
      end

      def initialize(data, transport, transports, plugins, source = nil)
        @logger          = Bolt::Logger.logger(self)
        @data            = data || {}
        @transport       = transport
        @config          = transports
        @config_resolved = transports.values.all?(&:resolved?)
        @plugins         = plugins
        @targets         = {}
        @source          = source
      end

      def version
        2
      end

      def target_implementation_class
        Bolt::Target
      end

      # Load and resolve the groups in the inventory. Loading groups resolves
      # all plugin references except for those for target data and config.
      #
      # @return [Bolt::Inventory::Group]
      #
      def groups
        @groups ||= Group.new(@data, @plugins, all_group: true).tap do |groups|
          groups.resolve_string_targets(groups.target_aliases, groups.all_targets)
          groups.validate
        end
      end

      # Return a list of all group names in the inventory.
      #
      # @return [Array[String]]
      #
      def group_names
        group_lookup.keys
      end

      # Return a map of all groups in the inventory.
      #
      # @return [Hash[String, Bolt::Inventory::Group]]
      #
      def group_lookup
        @group_lookup ||= groups.collect_groups
      end

      # Return a map of transport configuration for the inventory. Any
      # unresolved plugin references are resolved.
      #
      # @return [Hash[String, Bolt::Config::Transport]]
      #
      def config
        if @config_resolved
          @config
        else
          @config_resolved = true
          @config.each_value { |t| t.resolve(@plugins) unless t.resolved? }
        end
      end

      def group_names_for(target_name)
        group_data_for(target_name).fetch('groups', [])
      end

      def target_names
        groups.all_targets
      end
      # alias for analytics
      alias node_names target_names

      def get_targets(targets)
        target_array = expand_targets(targets)
        if target_array.is_a? Array
          target_array.flatten.uniq(&:name)
        else
          [target_array]
        end
      end

      def get_target(target)
        target_array = get_targets(target)
        if target_array.count > 1
          raise ValidationError.new("'#{target}' refers to #{target_array.count} targets", nil)
        end
        target_array.first
      end

      #### PRIVATE ####
      def group_data_for(target_name)
        groups.group_collect(target_name)
      end

      # If target is a group name, expand it to the members of that group.
      # Else match against targets in inventory by name or alias.
      # If a wildcard string, error if no matches are found.
      # Else fall back to [target] if no matches are found.
      def resolve_name(target)
        if (group = group_lookup[target])
          group.all_targets
        else
          # Try to wildcard match targets in inventory
          # Ignore case because hostnames are generally case-insensitive
          regexp = Regexp.new("^#{Regexp.escape(target).gsub('\*', '.*?')}$", Regexp::IGNORECASE)

          targets = groups.all_targets.select { |targ| targ =~ regexp }
          targets += groups.target_aliases.select { |target_alias, _target| target_alias =~ regexp }.values

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
        case targets
        when Bolt::Target
          targets
        when Array
          targets.map { |tish| expand_targets(tish) }
        when String
          # Expand a comma-separated list
          targets.split(/[[:space:],]+/).reject(&:empty?).map do |name|
            ts = resolve_name(name)
            ts.map do |t|
              # If the target doesn't exist, evaluate it from the inventory.
              # Then return a Bolt::Target.
              unless @targets.key?(t)
                @targets[t] = create_target_from_inventory(t)
              end
              Bolt::Target.new(t, self)
            end
          end
        end
      end
      private :expand_targets

      def remove_target(current_group, target, desired_group)
        if current_group.name == desired_group
          current_group.remove_target(target)
          target.invalidate_group_cache!
        end
        current_group.groups.each do |child_group|
          # If target was in current group, remove it from all child groups
          if current_group.name == desired_group
            remove_target(child_group, target, child_group.name)
          else
            remove_target(child_group, target, desired_group)
          end
        end
      end
      private :remove_target

      def add_target(current_group, target, desired_group)
        if current_group.name == desired_group
          current_group.add_target(target)
          target.invalidate_group_cache!
          return true
        end
        # Recurse on children Groups if not desired_group
        current_group.groups.each do |child_group|
          add_target(child_group, target, desired_group)
        end
      end
      private :add_target

      # Pull in a target definition from the inventory file and evaluate any
      # associated references. This is used when a target is resolved by
      # get_targets.
      def create_target_from_inventory(target_name)
        target_data = groups.target_collect(target_name) || { 'uri' => target_name }

        target = Bolt::Inventory::Target.new(target_data, self)
        @targets[target.name] = target

        add_to_group([target], 'all')

        target
      end

      # Add a brand new target, overriding any existing target with the same
      # name. This method does not honor target config from the inventory. This
      # is used when Target.new is called from a plan or with a data hash.
      def create_target_from_hash(data)
        # If target already exists, delete old and replace with new, otherwise add to new to all group
        new_target = Bolt::Inventory::Target.new(data, self)
        existing_target = @targets.key?(new_target.name)

        validate_target_from_hash(new_target)
        @targets[new_target.name] = new_target

        if existing_target
          clear_alia_from_group(groups, new_target.name)
        else
          add_to_group([new_target], 'all')
        end

        if new_target.target_alias
          groups.insert_alia(new_target.name, Array(new_target.target_alias))
        end

        new_target
      end

      def validate_target_from_hash(target)
        used_groups  = Set.new(group_names)
        used_targets = target_names

        # Make sure there are no group name conflicts
        if used_groups.include?(target.name)
          raise ValidationError.new("Target name #{target.name} conflicts with group of the same name", nil)
        end

        # Validate any aliases
        if (aliases = target.target_alias)
          unless aliases.is_a?(Array) || aliases.is_a?(String)
            msg = "Alias entry on #{t_name} must be a String or Array, not #{aliases.class}"
            raise ValidationError.new(msg, @name)
          end
        end

        # Make sure there are no conflicts with the new target aliases
        used_aliases = groups.target_aliases
        Array(target.target_alias).each do |alia|
          if used_groups.include?(alia)
            raise ValidationError.new("Alias #{alia} conflicts with group of the same name", nil)
          elsif used_targets.include?(alia)
            raise ValidationError.new("Alias #{alia} conflicts with target of the same name", nil)
          elsif used_aliases[alia] && used_aliases[alia] != target.name
            raise ValidationError.new(
              "Alias #{alia} refers to multiple targets: #{used_aliases[alia]} and #{target.name}", nil
            )
          end
        end
      end

      def clear_alia_from_group(group, target_name)
        if group.all_target_names.include?(target_name)
          group.clear_alia(target_name)
        end
        group.groups.each do |grp|
          clear_alia_from_group(grp, target_name)
        end
      end

      def remove_from_group(target, desired_group)
        unless target.length == 1
          raise ValidationError.new("'remove_from_group' expects a single Target, got #{target.length}", nil)
        end

        if desired_group == 'all'
          raise ValidationError.new("Cannot remove Target from Group 'all'", nil)
        end

        if group_names.include?(desired_group)
          remove_target(groups, @targets[target.first.name], desired_group)
        else
          raise ValidationError.new("Group #{desired_group} does not exist in inventory", nil)
        end
      end

      def add_to_group(targets, desired_group)
        if group_names.include?(desired_group)
          targets.each do |target|
            # Add the inventory copy of the target
            add_target(groups, @targets[target.name], desired_group)
          end
        else
          raise ValidationError.new("Group #{desired_group} does not exist in inventory", nil)
        end
      end

      def transport_data_get
        { transport: transport, transports: config.transform_values(&:to_h) }
      end

      def set_var(target, var_hash)
        @targets[target.name].set_var(var_hash)
      end

      def vars(target)
        @targets[target.name].vars
      end

      def add_facts(target, new_facts = {})
        @targets[target.name].add_facts(new_facts)
        target
      end

      def facts(target)
        @targets[target.name].facts
      end

      def set_feature(target, feature, value = true)
        @targets[target.name].set_feature(feature, value)
      end

      def features(target)
        @targets[target.name].features
      end

      def plugin_hooks(target)
        @targets[target.name].plugin_hooks
      end

      def set_config(target, key_or_key_path, value)
        @targets[target.name].set_config(key_or_key_path, value)
      end

      def target_config(target)
        @targets[target.name].config
      end

      def resources(target)
        @targets[target.name].resources
      end

      def resource(target, type, title)
        @targets[target.name].resource(type, title)
      end
    end
  end
end
