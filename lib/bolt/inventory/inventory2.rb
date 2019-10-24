# frozen_string_literal: true

require 'bolt/inventory/group2'
require 'bolt/inventory/target'

module Bolt
  class Inventory
    class Inventory2
      attr_reader :targets, :plugins, :config
      # This uses "targets" in the message instead of "nodes"
      class WildcardError < Bolt::Error
        def initialize(target)
          super("Found 0 targets matching wildcard pattern #{target}", 'bolt.inventory/wildcard-error')
        end
      end

      def initialize(data, config = nil, plugins: nil)
        @logger = Logging.logger[self]
        # Config is saved to add config options to targets
        @config = config || Bolt::Config.default
        @data = data || {}
        @groups = Group2.new(@data.merge('name' => 'all'), plugins)
        @plugins = plugins
        @group_lookup = {}
        # The targets hash is the canonical source for all targets in inventory
        @targets = {}
        @groups.resolve_string_targets(@groups.target_aliases, @groups.all_targets)
        collect_groups
      end

      def validate
        @groups.validate
      end

      def version
        2
      end

      def target_implementation_class
        Bolt::Target2
      end

      def collect_groups
        # Provide a lookup map for finding a group by name
        @group_lookup = @groups.collect_groups
      end

      def group_names
        @group_lookup.keys
      end

      def target_names
        @groups.all_targets
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

      def data_hash
        {
          data: {},
          target_hash: {
            target_vars: {},
            target_facts: {},
            target_features: {}
          },
          config: @config.transport_data_get
        }
      end

      #### PRIVATE ####
      def group_data_for(target_name)
        @groups.group_collect(target_name)
      end

      # If target is a group name, expand it to the members of that group.
      # Else match against targets in inventory by name or alias.
      # If a wildcard string, error if no matches are found.
      # Else fall back to [target] if no matches are found.
      def resolve_name(target)
        if (group = @group_lookup[target])
          group.all_targets
        else
          # Try to wildcard match targets in inventory
          # Ignore case because hostnames are generally case-insensitive
          regexp = Regexp.new("^#{Regexp.escape(target).gsub('\*', '.*?')}$", Regexp::IGNORECASE)

          targets = @groups.all_targets.select { |targ| targ =~ regexp }
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
        if targets.is_a? Bolt::Target2
          targets
        elsif targets.is_a? Array
          targets.map { |tish| expand_targets(tish) }
        elsif targets.is_a? String
          # Expand a comma-separated list
          targets.split(/[[:space:],]+/).reject(&:empty?).map do |name|
            ts = resolve_name(name)
            ts.map do |t|
              # If the target doesn't exist, evaluate it from the inventory.
              # Then return a Bolt::Target2.
              unless @targets.key?(t)
                @targets[t] = create_target_from_inventory(t)
              end
              Bolt::Target2.new(t, self)
            end
          end
        end
      end
      private :expand_targets

      def add_target(current_group, target, desired_group)
        if current_group.name == desired_group
          current_group.add_target(target)
          @groups.validate
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
        target_data = @groups.target_collect(target_name) || { 'uri' => target_name }

        target = Bolt::Inventory::Target.new(target_data, self)
        @targets[target.name] = target

        add_to_group([target], 'all')

        target
      end

      # Add a brand new target, overriding any existing target with the same
      # name. This method does not honor target config from the inventory. This
      # is used when Target.new is called from a plan.
      def create_target_from_plan(data)
        # If target already exists, delete old and replace with new, otherwise add to new to all group
        new_target = Bolt::Inventory::Target.new(data, self)
        existing_target = @targets.key?(new_target.name)
        @targets[new_target.name] = new_target

        unless existing_target
          add_to_group([new_target], 'all')
        end

        new_target
      end

      def add_to_group(targets, desired_group)
        if group_names.include?(desired_group)
          targets.each do |target|
            if group_names.include?(target.name)
              raise ValidationError.new("Group #{target.name} conflicts with target of the same name", target.name)
            end
            # Add the inventory copy of the target
            add_target(@groups, @targets[target.name], desired_group)
          end
        else
          raise ValidationError.new("Group #{desired_group} does not exist in inventory", nil)
        end
      end

      def set_var(target, var_hash)
        @targets[target.name].set_var(var_hash)
      end

      def vars(target)
        @targets[target.name].vars
      end

      def add_facts(target, new_facts = {})
        @targets[target.name].add_facts(new_facts)
        # rubocop:disable Style/GlobalVars
        $future ? target : facts(target)
        # rubocop:enable Style/GlobalVars
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
    end
  end
end
