# frozen_string_literal: true

require 'bolt/inventory/group'

module Bolt
  class Inventory
    class Group2
      attr_accessor :name, :nodes, :aliases, :name_or_alias, :groups, :config, :rest, :facts, :vars, :features

      # THESE are duplicates with the old groups for now.
      # Regex used to validate group names and target aliases.
      NAME_REGEX = /\A[a-z0-9_][a-z0-9_-]*\Z/.freeze

      DATA_KEYS = %w[name config facts vars features].freeze
      NODE_KEYS = DATA_KEYS + %w[alias uri]
      GROUP_KEYS = DATA_KEYS + %w[groups nodes]
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

        nodes = fetch_value(data, 'nodes', Array)
        groups = fetch_value(data, 'groups', Array)

        @nodes = {}
        @aliases = {}
        nodes.reject { |node| node.is_a?(String) }.each do |node|
          unless node.is_a?(Hash)
            raise ValidationError.new("Node entry must be a String or Hash, not #{node.class}", @name)
          end

          node['name'] ||= node['uri']

          if node['name'].nil? || node['name'].empty?
            raise ValidationError.new("No name or uri for node: #{node}", @name)
          end

          if @nodes.include?(node['name'])
            @logger.warn("Ignoring duplicate node in #{@name}: #{node}")
            next
          end

          raise ValidationError.new("Node #{node} does not have a name", @name) unless node['name']
          @nodes[node['name']] = node

          unless (unexpected_keys = node.keys - NODE_KEYS).empty?
            msg = "Found unexpected key(s) #{unexpected_keys.join(', ')} in node #{node['name']}"
            @logger.warn(msg)
          end
          config_keys = node['config']&.keys || []
          unless (unexpected_keys = config_keys - CONFIG_KEYS).empty?
            msg = "Found unexpected key(s) #{unexpected_keys.join(', ')} in config for node #{node['name']}"
            @logger.warn(msg)
          end

          next unless node.include?('alias')

          aliases = node['alias']
          aliases = [aliases] if aliases.is_a?(String)
          unless aliases.is_a?(Array)
            msg = "Alias entry on #{node['name']} must be a String or Array, not #{aliases.class}"
            raise ValidationError.new(msg, @name)
          end

          aliases.each do |alia|
            raise ValidationError.new("Invalid alias #{alia}", @name) unless alia =~ NAME_REGEX

            if (found = @aliases[alia])
              raise ValidationError.new(alias_conflict(alia, found, node['name']), @name)
            end
            @aliases[alia] = node['name']
          end
        end

        # If node is a string, it can refer to either a node name or alias. Which can't be determined
        # until all groups have been resolved, and requires a depth-first traversal to categorize them.
        @name_or_alias = nodes.select { |node| node.is_a?(String) }

        @groups = groups.map { |g| Group2.new(g) }
      end

      def node_data(node_name)
        if (data = @nodes[node_name])
          { 'config' => data['config'] || {},
            'vars' => data['vars'] || {},
            'facts' => data['facts'] || {},
            'features' => data['features'] || [],
            # This allows us to determine if a node was found?
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

      def resolve_aliases(aliases, node_names)
        @name_or_alias.each do |name_or_alias|
          # If an alias is found, insert the name into this group. Otherwise use the name as a new node's uri.
          if node_names.include?(name_or_alias)
            @nodes[name_or_alias] = { 'name' => name_or_alias }
          elsif (node_name = aliases[name_or_alias])
            if @nodes.include?(node_name)
              @logger.warn("Ignoring duplicate node in #{@name}: #{node_name}")
            else
              @nodes[node_name] = { 'name' => node_name }
            end
          else
            node_name = name_or_alias

            if @nodes.include?(node_name)
              @logger.warn("Ignoring duplicate node in #{@name}: #{node_name}")
            else
              @nodes[node_name] = { 'uri' => node_name }
            end
          end
        end

        @groups.each { |g| g.resolve_aliases(aliases, node_names) }
      end

      private def alias_conflict(name, node1, node2)
        "Alias #{name} refers to multiple targets: #{node1} and #{node2}"
      end

      private def group_alias_conflict(name)
        "Group #{name} conflicts with alias of the same name"
      end

      private def group_node_conflict(name)
        "Group #{name} conflicts with node of the same name"
      end

      private def alias_node_conflict(name)
        "Node name #{name} conflicts with alias of the same name"
      end

      def validate(used_names = Set.new, node_names = Set.new, aliased = {}, depth = 0)
        # Test if this group name conflicts with anything used before.
        raise ValidationError.new("Tried to redefine group #{@name}", @name) if used_names.include?(@name)
        raise ValidationError.new(group_node_conflict(@name), @name) if node_names.include?(@name)
        raise ValidationError.new(group_alias_conflict(@name), @name) if aliased.include?(@name)

        used_names << @name

        # Collect node names and aliases into a list used to validate that subgroups don't conflict.
        # Used names validate that previously used group names don't conflict with new node names/aliases.
        @nodes.each_key do |n|
          # Require nodes to be parseable as a Target.
          begin
            Target.new(n)
          rescue Bolt::ParseError => e
            @logger.debug(e)
            raise ValidationError.new("Invalid node name #{n}", @name)
          end

          raise ValidationError.new(group_node_conflict(n), @name) if used_names.include?(n)
          if aliased.include?(n)
            raise ValidationError.new(alias_node_conflict(n), @name)
          end

          node_names << n
        end

        @aliases.each do |n, target|
          raise ValidationError.new(group_alias_conflict(n), @name) if used_names.include?(n)
          if node_names.include?(n)
            raise ValidationError.new(alias_node_conflict(n), @name)
          end

          if aliased.include?(n)
            raise ValidationError.new(alias_conflict(n, target, aliased[n]), @name)
          end

          aliased[n] = target
        end

        @groups.each do |g|
          begin
            g.validate(used_names, node_names, aliased, depth + 1)
          rescue ValidationError => e
            e.add_parent(@name)
            raise e
          end
        end

        nil
      end

      # The data functions below expect and return nil or a hash of the schema
      # { 'config' => Hash , 'vars' => Hash, 'facts' => Hash, 'features' => Array, groups => Array }
      def data_for(node_name)
        data_merge(group_collect(node_name), node_collect(node_name))
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

      # Returns all nodes contained within the group, which includes nodes from subgroups.
      def node_names
        @groups.inject(local_node_names) do |acc, g|
          acc.merge(g.node_names)
        end
      end

      # Returns a mapping of aliases to nodes contained within the group, which includes subgroups.
      def node_aliases
        @groups.inject(@aliases) do |acc, g|
          acc.merge(g.node_aliases)
        end
      end

      # Return a mapping of group names to group.
      def collect_groups
        @groups.inject(name => self) do |acc, g|
          acc.merge(g.collect_groups)
        end
      end

      def local_node_names
        Set.new(@nodes.keys)
      end
      private :local_node_names

      def node_collect(node_name)
        data = @groups.inject(nil) do |acc, g|
          if (d = g.node_collect(node_name))
            data_merge(d, acc)
          else
            acc
          end
        end
        data_merge(node_data(node_name), data)
      end

      def group_collect(node_name)
        data = @groups.inject(nil) do |acc, g|
          if (d = g.data_for(node_name))
            data_merge(d, acc)
          else
            acc
          end
        end

        if data
          data_merge(group_data, data)
        elsif @nodes.include?(node_name)
          group_data
        end
      end
    end
  end
end
