# frozen_string_literal: true

require 'bolt/inventory/group'

module Bolt
  class Inventory
    class Group2
      attr_accessor :name, :targets, :aliases, :name_or_alias, :groups, :config, :rest, :facts, :vars, :features

      # THESE are duplicates with the old groups for now.
      # Regex used to validate group names and target aliases.
      NAME_REGEX = /\A[a-z0-9_][a-z0-9_-]*\Z/.freeze

      DATA_KEYS = %w[name config facts vars features].freeze
      NODE_KEYS = DATA_KEYS + %w[alias uri]
      GROUP_KEYS = DATA_KEYS + %w[groups targets]
      CONFIG_KEYS = Bolt::TRANSPORTS.keys.map(&:to_s) + ['transport']

      def initialize(data)
        @logger = Logging.logger[self]

        raise ValidationError.new("Expected group to be a Hash, not #{data.class}", nil) unless data.is_a?(Hash)
        raise ValidationError.new("Group does not have a name", nil) unless data.key?('name')

        @name = data['name']
        raise ValidationError.new("Group name must be a String, not #{@name.inspect}", nil) unless @name.is_a?(String)
        raise ValidationError.new("Invalid group name #{@name}", @name) unless @name =~ NAME_REGEX

        unless (unexpected_keys = data.keys - GROUP_KEYS).empty?
          msg = "Found unexpected key(s) #{unexpected_keys.join(', ')} in group #{@name}"
          @logger.warn(msg)
        end

        @vars = fetch_value(data, 'vars', Hash)
        @facts = fetch_value(data, 'facts', Hash)
        @features = fetch_value(data, 'features', Array)
        @config = fetch_value(data, 'config', Hash)

        unless (unexpected_keys = @config.keys - CONFIG_KEYS).empty?
          msg = "Found unexpected key(s) #{unexpected_keys.join(', ')} in config for group #{@name}"
          @logger.warn(msg)
        end

        targets = fetch_value(data, 'targets', Array)
        groups = fetch_value(data, 'groups', Array)

        @targets = {}
        @aliases = {}
        targets.reject { |target| target.is_a?(String) }.each do |target|
          unless target.is_a?(Hash)
            raise ValidationError.new("Node entry must be a String or Hash, not #{target.class}", @name)
          end

          target['name'] ||= target['uri']

          if target['name'].nil? || target['name'].empty?
            raise ValidationError.new("No name or uri for target: #{target}", @name)
          end

          if @targets.include?(target['name'])
            @logger.warn("Ignoring duplicate target in #{@name}: #{target}")
            next
          end

          raise ValidationError.new("Node #{target} does not have a name", @name) unless target['name']
          @targets[target['name']] = target

          unless (unexpected_keys = target.keys - NODE_KEYS).empty?
            msg = "Found unexpected key(s) #{unexpected_keys.join(', ')} in target #{target['name']}"
            @logger.warn(msg)
          end
          config_keys = target['config']&.keys || []
          unless (unexpected_keys = config_keys - CONFIG_KEYS).empty?
            msg = "Found unexpected key(s) #{unexpected_keys.join(', ')} in config for target #{target['name']}"
            @logger.warn(msg)
          end

          next unless target.include?('alias')

          aliases = target['alias']
          aliases = [aliases] if aliases.is_a?(String)
          unless aliases.is_a?(Array)
            msg = "Alias entry on #{target['name']} must be a String or Array, not #{aliases.class}"
            raise ValidationError.new(msg, @name)
          end

          aliases.each do |alia|
            raise ValidationError.new("Invalid alias #{alia}", @name) unless alia =~ NAME_REGEX

            if (found = @aliases[alia])
              raise ValidationError.new(alias_conflict(alia, found, target['name']), @name)
            end
            @aliases[alia] = target['name']
          end
        end

        # If target is a string, it can refer to either a target name or alias. Which can't be determined
        # until all groups have been resolved, and requires a depth-first traversal to categorize them.
        @name_or_alias = targets.select { |target| target.is_a?(String) }

        @groups = groups.map { |g| Group2.new(g) }
      end

      def target_data(target_name)
        if (data = @targets[target_name])
          { 'config' => data['config'] || {},
            'vars' => data['vars'] || {},
            'facts' => data['facts'] || {},
            'features' => data['features'] || [],
            # This allows us to determine if a target was found?
            'name' => data['name'] || nil,
            'uri' => data['uri'] || nil,
            # groups come from group_data
            'groups' => [] }
        end
      end

      def data_merge(data1, data2)
        if data2.nil? || data1.nil?
          return data2 || data1
        end

        {
          'config' => Bolt::Util.deep_merge(data1['config'], data2['config']),
          'name' => data1['name'] || data2['name'],
          'uri' => data1['uri'] || data2['uri'],
          # Shallow merge instead of deep merge so that vars with a hash value
          # are assigned a new hash, rather than merging the existing value
          # with the value meant to replace it
          'vars' => data1['vars'].merge(data2['vars']),
          'facts' => Bolt::Util.deep_merge(data1['facts'], data2['facts']),
          'features' => data1['features'] | data2['features'],
          'groups' => data2['groups'] + data1['groups']
        }
      end

      private def fetch_value(data, key, type)
        value = data.fetch(key, type.new)
        unless value.is_a?(type)
          raise ValidationError.new("Expected #{key} to be of type #{type}, not #{value.class}", @name)
        end
        value
      end

      def resolve_aliases(aliases, target_names)
        @name_or_alias.each do |name_or_alias|
          # If an alias is found, insert the name into this group. Otherwise use the name as a new target's uri.
          if target_names.include?(name_or_alias)
            @targets[name_or_alias] = { 'name' => name_or_alias }
          elsif (target_name = aliases[name_or_alias])
            if @targets.include?(target_name)
              @logger.warn("Ignoring duplicate target in #{@name}: #{target_name}")
            else
              @targets[target_name] = { 'name' => target_name }
            end
          else
            target_name = name_or_alias

            if @targets.include?(target_name)
              @logger.warn("Ignoring duplicate target in #{@name}: #{target_name}")
            else
              @targets[target_name] = { 'uri' => target_name }
            end
          end
        end

        @groups.each { |g| g.resolve_aliases(aliases, target_names) }
      end

      private def alias_conflict(name, target1, target2)
        "Alias #{name} refers to multiple targets: #{target1} and #{target2}"
      end

      private def group_alias_conflict(name)
        "Group #{name} conflicts with alias of the same name"
      end

      private def group_target_conflict(name)
        "Group #{name} conflicts with target of the same name"
      end

      private def alias_target_conflict(name)
        "Node name #{name} conflicts with alias of the same name"
      end

      def validate(used_names = Set.new, target_names = Set.new, aliased = {}, depth = 0)
        # Test if this group name conflicts with anything used before.
        raise ValidationError.new("Tried to redefine group #{@name}", @name) if used_names.include?(@name)
        raise ValidationError.new(group_target_conflict(@name), @name) if target_names.include?(@name)
        raise ValidationError.new(group_alias_conflict(@name), @name) if aliased.include?(@name)

        used_names << @name

        # Collect target names and aliases into a list used to validate that subgroups don't conflict.
        # Used names validate that previously used group names don't conflict with new target names/aliases.
        @targets.each_key do |n|
          # Require targets to be parseable as a Target.
          begin
            Target.new(n)
          rescue Bolt::ParseError => e
            @logger.debug(e)
            raise ValidationError.new("Invalid target name #{n}", @name)
          end

          raise ValidationError.new(group_target_conflict(n), @name) if used_names.include?(n)
          if aliased.include?(n)
            raise ValidationError.new(alias_target_conflict(n), @name)
          end

          target_names << n
        end

        @aliases.each do |n, target|
          raise ValidationError.new(group_alias_conflict(n), @name) if used_names.include?(n)
          if target_names.include?(n)
            raise ValidationError.new(alias_target_conflict(n), @name)
          end

          if aliased.include?(n)
            raise ValidationError.new(alias_conflict(n, target, aliased[n]), @name)
          end

          aliased[n] = target
        end

        @groups.each do |g|
          begin
            g.validate(used_names, target_names, aliased, depth + 1)
          rescue ValidationError => e
            e.add_parent(@name)
            raise e
          end
        end

        nil
      end

      # The data functions below expect and return nil or a hash of the schema
      # { 'config' => Hash , 'vars' => Hash, 'facts' => Hash, 'features' => Array, groups => Array }
      def data_for(target_name)
        data_merge(group_collect(target_name), target_collect(target_name))
      end

      def group_data
        { 'config' => @config,
          'vars' => @vars,
          'facts' => @facts,
          'features' => @features,
          'groups' => [@name] }
      end

      def empty_data
        { 'config' => {},
          'vars' => {},
          'facts' => {},
          'features' => [],
          'groups' => [] }
      end

      # Returns all targets contained within the group, which includes targets from subgroups.
      def target_names
        @groups.inject(local_target_names) do |acc, g|
          acc.merge(g.target_names)
        end
      end

      # Returns a mapping of aliases to targets contained within the group, which includes subgroups.
      def target_aliases
        @groups.inject(@aliases) do |acc, g|
          acc.merge(g.target_aliases)
        end
      end

      # Return a mapping of group names to group.
      def collect_groups
        @groups.inject(name => self) do |acc, g|
          acc.merge(g.collect_groups)
        end
      end

      def local_target_names
        Set.new(@targets.keys)
      end
      private :local_target_names

      def target_collect(target_name)
        data = @groups.inject(nil) do |acc, g|
          if (d = g.target_collect(target_name))
            data_merge(d, acc)
          else
            acc
          end
        end
        data_merge(target_data(target_name), data)
      end

      def group_collect(target_name)
        data = @groups.inject(nil) do |acc, g|
          if (d = g.data_for(target_name))
            data_merge(d, acc)
          else
            acc
          end
        end

        if data
          data_merge(group_data, data)
        elsif @targets.include?(target_name)
          group_data
        end
      end
    end
  end
end
