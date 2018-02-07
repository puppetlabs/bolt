module Bolt
  class Inventory
    # Group is a specific implementation of Inventory based on nested
    # structured data.
    class Group
      attr_accessor :name, :nodes, :groups, :config, :rest

      def initialize(data)
        @name = data['name']

        @nodes = if data['nodes']
                   data['nodes'].map do |n|
                     if n.is_a? String
                       { 'name' => n }
                     else
                       n
                     end
                   end
                 else
                   []
                 end
        @config = data['config'] || {}
        @groups = if data['groups']
                    data['groups'].map { |g| Group.new(g) }
                  else
                    []
                  end

        # this allows arbitrary info for the top level
        @rest = data.reject { |k, _| %w[name nodes config groups].include? k }
      end

      def validate(used_names = Set.new, node_names = Set.new, depth = 0)
        raise ValidationError.new("Group does not have a name", nil) unless @name
        if used_names.include?(@name)
          raise ValidationError.new("Tried to redefine group #{@name}", @name)
        end
        raise ValidationError.new("Invalid Group name #{@name}", @name) unless @name =~ /\A[a-z0-9_]+\Z/

        if node_names.include?(@name)
          raise ValidationError.new("Group #{@name} conflicts with node of the same name", @name)
        end
        raise ValidationError.new("Group #{@name} is too deeply nested", @name) if depth > 1

        used_names << @name

        @nodes.each do |n|
          raise ValidationError.new("node #{n['name']} does not have a name", n['name']) unless n['name']
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
      # { 'config' => Hash , groups => Array }
      # As we add more options beyond config this schema will grow
      def data_for(node_name)
        data_merge(group_collect(node_name), node_collect(node_name))
      end

      def node_data(node_name)
        if (data = @nodes.find { |n| n['name'] == node_name })
          { 'config' => data['config'] || {},
            # groups come from group_data
            'groups' => [] }
        end
      end

      def group_data
        { 'config' => @config,
          'groups' => [@name] }
      end

      def empty_data
        { 'config' => {},
          'groups' => [] }
      end

      def data_merge(data1, data2)
        if data2.nil? || data1.nil?
          return data2 || data1
        end

        {
          'config' => Bolt::Util.deep_merge(data1['config'], data2['config']),
          'groups' => data2['groups'] + data1['groups']
        }
      end

      def node_names
        @_node_names ||= Set.new(nodes.map { |n| n['name'] })
      end

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
        elsif node_names.include?(node_name)
          group_data
        end
      end
    end
  end
end
