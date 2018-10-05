# frozen_string_literal: true

module Bolt
  class Inventory
    # Group is a specific implementation of Inventory based on nested
    # structured data.
    class Group
      attr_accessor :name, :nodes, :groups, :config, :rest

      def initialize(data)
        @logger = Logging.logger[self]

        unless data.is_a?(Hash)
          raise ValidationError.new("Expected group to be a Hash, not #{data.class}", nil)
        end

        if data.key?('name')
          if data['name'].is_a?(String)
            @name = data['name']
          else
            raise ValidationError.new("Group name must be a String, not #{data['name'].inspect}", nil)
          end
        else
          raise ValidationError.new("Group does not have a name", nil)
        end

        @vars = fetch_value(data, 'vars', Hash)
        @facts = fetch_value(data, 'facts', Hash)
        @features = fetch_value(data, 'features', Array)
        @config = fetch_value(data, 'config', Hash)

        nodes = fetch_value(data, 'nodes', Array)
        groups = fetch_value(data, 'groups', Array)

        @nodes = {}
        nodes.each do |node|
          node = { 'name' => node } if node.is_a? String
          unless node.is_a?(Hash)
            raise ValidationError.new("Node entry must be a String or Hash, not #{node.class}", @name)
          end
          if @nodes.include? node['name']
            @logger.warn("Ignoring duplicate node in #{@name}: #{node}")
          else
            @nodes[node['name']] = node
          end
        end

        @groups = groups.map { |g| Group.new(g) }

        # this allows arbitrary info for the top level
        @rest = data.reject { |k, _| %w[name nodes config groups vars facts features].include? k }
      end

      def fetch_value(data, key, type)
        value = data.fetch(key, type.new)
        unless value.is_a?(type)
          raise ValidationError.new("Expected #{key} to be of type #{type}, not #{value.class}", @name)
        end
        value
      end

      def validate(used_names = Set.new, node_names = Set.new, depth = 0)
        if used_names.include?(@name)
          raise ValidationError.new("Tried to redefine group #{@name}", @name)
        end
        raise ValidationError.new("Invalid group name #{@name}", @name) unless @name =~ /\A[a-z0-9_]+\Z/

        if node_names.include?(@name)
          raise ValidationError.new("Group #{@name} conflicts with node of the same name", @name)
        end

        used_names << @name

        @nodes.each_value do |n|
          # Require nodes to be parseable as a Target.
          begin
            Target.new(n['name'])
          rescue Addressable::URI::InvalidURIError => e
            @logger.debug(e)
            raise ValidationError.new("Invalid node name #{n['name']}", n['name'])
          end

          raise ValidationError.new("Node #{n['name']} does not have a name", n['name']) unless n['name']
          if used_names.include?(n['name'])
            raise ValidationError.new("Group #{n['name']} conflicts with node of the same name", n['name'])
          end

          node_names << n['name']
        end

        @groups.each do |g|
          begin
            g.validate(used_names, node_names, depth + 1)
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

      def node_data(node_name)
        if (data = @nodes[node_name])
          { 'config' => data['config'] || {},
            'vars' => data['vars'] || {},
            'facts' => data['facts'] || {},
            'features' => data['features'] || [],
            # groups come from group_data
            'groups' => [] }
        end
      end

      def group_data
        { 'config'   => @config,
          'vars'     => @vars,
          'facts'    => @facts,
          'features' => @features,
          'groups'   => [@name] }
      end

      def empty_data
        { 'config'   => {},
          'vars'     => {},
          'facts'    => {},
          'features' => [],
          'groups'   => [] }
      end

      def data_merge(data1, data2)
        if data2.nil? || data1.nil?
          return data2 || data1
        end

        {
          'config' => Bolt::Util.deep_merge(data1['config'], data2['config']),
          # Shallow merge instead of deep merge so that vars with a hash value
          # are assigned a new hash, rather than merging the existing value
          # with the value meant to replace it
          'vars'   => data1['vars'].merge(data2['vars']),
          'facts'  => Bolt::Util.deep_merge(data1['facts'], data2['facts']),
          'features' => data1['features'] | data2['features'],
          'groups' => data2['groups'] + data1['groups']
        }
      end

      # Returns all nodes contained within the group, which includes nodes from subgroups.
      def node_names
        @groups.inject(local_node_names) do |acc, g|
          acc.merge(g.node_names)
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
