# frozen_string_literal: true

require 'bolt/inventory/group'
require 'bolt/inventory/inventory'
require 'bolt/inventory/target'

module Bolt
  class Inventory
    class Group
      attr_accessor :name, :groups

      # Regex used to validate group names and target aliases.
      NAME_REGEX = /\A[a-z0-9_][a-z0-9_-]*\Z/.freeze

      # NOTE: All keys should have a corresponding schema property in schemas/bolt-inventory.schema.json
      DATA_KEYS = %w[config facts vars features plugin_hooks].freeze
      TARGET_KEYS = DATA_KEYS + %w[name alias uri]
      GROUP_KEYS = DATA_KEYS + %w[name groups targets]
      CONFIG_KEYS = Bolt::Config::TRANSPORT_CONFIG.keys + ['transport']

      def initialize(input, plugins)
        @logger = Logging.logger[self]
        @plugins = plugins

        input = @plugins.resolve_top_level_references(input) if @plugins.reference?(input)

        raise ValidationError.new("Group does not have a name", nil) unless input.key?('name')

        @name = @plugins.resolve_references(input['name'])

        raise ValidationError.new("Group name must be a String, not #{@name.inspect}", nil) unless @name.is_a?(String)
        raise ValidationError.new("Invalid group name #{@name}", @name) unless @name =~ NAME_REGEX

        validate_group_input(input)

        @input = input

        validate_data_keys(@input)

        targets = @plugins.resolve_top_level_references(input.fetch('targets', []))

        @unresolved_targets = {}
        @resolved_targets = {}

        @aliases = {}
        @string_targets = []

        Array(targets).each do |target|
          # If target is a string, it can either be trivially defining a target
          # or it could be a name/alias of a target defined in another group.
          # We can't tell the difference until all groups have been resolved,
          # so we store the string on its own here and process it later.
          if target.is_a?(String)
            @string_targets << target
          # Handle plugins at this level so that lookups cannot trigger recursive lookups
          elsif target.is_a?(Hash)
            add_target_definition(target)
          else
            raise ValidationError.new("Target entry must be a String or Hash, not #{target.class}", @name)
          end
        end

        groups = input.fetch('groups', [])
        # 'groups' can be a _plugin reference, in which case we want to resolve
        # it. That can itself return a reference, so we want to keep resolving
        # them until we have a value. We don't just use resolve_references
        # though, since that will resolve any nested references and we want to
        # leave it to the group to do that lazily.
        groups = @plugins.resolve_top_level_references(groups)

        @groups = Array(groups).map { |g| Group.new(g, plugins) }
      end

      def target_data(target_name)
        if @unresolved_targets.key?(target_name)
          target = @unresolved_targets.delete(target_name)
          resolved_data = resolve_data_keys(target, target_name).merge(
            'name' => target['name'],
            'uri' => target['uri'],
            'alias' => target['alias'],
            # groups come from group_data
            'groups' => []
          )
          @resolved_targets[target_name] = resolved_data
        else
          @resolved_targets[target_name]
        end
      end

      def all_target_names
        @unresolved_targets.keys + @resolved_targets.keys
      end

      def add_target_definition(target)
        # This check ensures target lookup plugins do not returns bare strings.
        # Remove it if we decide to allows task plugins to return string Target
        # names.
        unless target.is_a?(Hash)
          raise ValidationError.new("Target entry must be a Hash, not #{target.class}", @name)
        end

        target['name'] = @plugins.resolve_references(target['name']) if target.key?('name')
        target['uri'] = @plugins.resolve_references(target['uri']) if target.key?('uri')
        target['alias'] = @plugins.resolve_references(target['alias']) if target.key?('alias')

        t_name = target['name'] || target['uri']

        if t_name.nil? || t_name.empty?
          raise ValidationError.new("No name or uri for target: #{target}", @name)
        end

        unless t_name.is_a? String
          raise ValidationError.new("Target name must be a String, not #{t_name.class}", @name)
        end

        unless t_name.ascii_only?
          raise ValidationError.new("Target name must be ASCII characters: #{target}", @name)
        end

        if contains_target?(t_name)
          @logger.warn("Ignoring duplicate target in #{@name}: #{target}")
          return
        end

        unless (unexpected_keys = target.keys - TARGET_KEYS).empty?
          msg = "Found unexpected key(s) #{unexpected_keys.join(', ')} in target #{t_name}"
          @logger.warn(msg)
        end

        validate_data_keys(target, t_name)

        if target.include?('alias')
          aliases = target['alias']
          aliases = [aliases] if aliases.is_a?(String)
          unless aliases.is_a?(Array)
            msg = "Alias entry on #{t_name} must be a String or Array, not #{aliases.class}"
            raise ValidationError.new(msg, @name)
          end

          insert_alia(t_name, aliases)
        end

        @unresolved_targets[t_name] = target
      end

      def remove_target(target)
        @resolved_targets.delete(target.name)
        @unresolved_targets.delete(target.name)
      end

      def add_target(target)
        @resolved_targets[target.name] = { 'name' => target.name }
      end

      def insert_alia(target_name, aliases)
        aliases.each do |alia|
          raise ValidationError.new("Invalid alias #{alia}", @name) unless alia =~ NAME_REGEX

          if (found = @aliases[alia])
            raise ValidationError.new(alias_conflict(alia, found, target_name), @name)
          end
          @aliases[alia] = target_name
        end
      end

      def clear_alia(target_name)
        @aliases.reject! { |_alias, name| name == target_name }
      end

      def data_merge(data1, data2)
        if data2.nil? || data1.nil?
          return data2 || data1
        end

        {
          'config' => Bolt::Util.deep_merge(data1['config'], data2['config']),
          'name' => data1['name'] || data2['name'],
          'uri' => data1['uri'] || data2['uri'],
          # Collect all aliases across all groups for each target uri
          'alias' => [*data1['alias'], *data2['alias']],
          # Shallow merge instead of deep merge so that vars with a hash value
          # are assigned a new hash, rather than merging the existing value
          # with the value meant to replace it
          'vars' => data1['vars'].merge(data2['vars']),
          'facts' => Bolt::Util.deep_merge(data1['facts'], data2['facts']),
          'features' => data1['features'] | data2['features'],
          'plugin_hooks' => data1['plugin_hooks'].merge(data2['plugin_hooks']),
          'groups' => data2['groups'] + data1['groups']
        }
      end

      def resolve_string_targets(aliases, known_targets)
        @string_targets.each do |string_target|
          # If this is the name of a target defined elsewhere, then insert the
          # target into this group as just a name. Otherwise, add a new target
          # with the string as the URI.
          if known_targets.include?(string_target)
            @unresolved_targets[string_target] = { 'name' => string_target }
          # If this is an alias for an existing target, then add it to this group
          elsif (canonical_name = aliases[string_target])
            if contains_target?(canonical_name)
              @logger.warn("Ignoring duplicate target in #{@name}: #{canonical_name}")
            else
              @unresolved_targets[canonical_name] = { 'name' => canonical_name }
            end
          # If it's not the name or alias of an existing target, then make a
          # new target using the string as the URI
          elsif contains_target?(string_target)
            @logger.warn("Ignoring duplicate target in #{@name}: #{string_target}")
          else
            @unresolved_targets[string_target] = { 'uri' => string_target }
          end
        end
        @groups.each { |g| g.resolve_string_targets(aliases, known_targets) }
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
        "Target name #{name} conflicts with alias of the same name"
      end

      def validate_group_input(input)
        raise ValidationError.new("Expected group to be a Hash, not #{input.class}", nil) unless input.is_a?(Hash)

        # DEPRECATION : remove this before finalization
        if input.key?('target-lookups')
          msg = "'target-lookups' are no longer a separate key. Merge 'target-lookups' and 'targets' lists and replace 'plugin' with '_plugin'" # rubocop:disable Layout/LineLength
          raise ValidationError.new(msg, @name)
        end

        if input.key?('nodes')
          msg = <<~MSG.chomp
                Found 'nodes' key in group #{@name}. This looks like a v1 inventory file, which is
                no longer supported by Bolt. Migrate to a v2 inventory file automatically using
                'bolt project migrate'.
                MSG
          raise ValidationError.new(msg, nil)
        end

        unless (unexpected_keys = input.keys - GROUP_KEYS).empty?
          msg = "Found unexpected key(s) #{unexpected_keys.join(', ')} in group #{@name}"
          @logger.warn(msg)
        end

        Bolt::Util.walk_keys(input) do |key|
          if @plugins.reference?(key)
            raise ValidationError.new("Group keys cannot be specified as _plugin references", @name)
          else
            key
          end
        end
      end

      def validate(used_group_names = Set.new, used_target_names = Set.new, used_aliases = {})
        # Test if this group name conflicts with anything used before.
        raise ValidationError.new("Tried to redefine group #{@name}", @name) if used_group_names.include?(@name)
        raise ValidationError.new(group_target_conflict(@name), @name) if used_target_names.include?(@name)
        raise ValidationError.new(group_alias_conflict(@name), @name) if used_aliases.include?(@name)

        used_group_names << @name

        # Collect target names and aliases into a list used to validate that subgroups don't conflict.
        # Used names validate that previously used group names don't conflict with new target names/aliases.
        @unresolved_targets.merge(@resolved_targets).each do |t_name, t_data|
          # Require targets to be parseable as a Target.
          begin
            # Catch malformed URI here
            Bolt::Inventory::Target.parse_uri(t_data['uri'])
          rescue Bolt::ParseError => e
            @logger.debug(e)
            raise ValidationError.new("Invalid target uri #{t_data['uri']}", @name)
          end

          raise ValidationError.new(group_target_conflict(t_name), @name) if used_group_names.include?(t_name)
          if used_aliases.include?(t_name)
            raise ValidationError.new(alias_target_conflict(t_name), @name)
          end

          used_target_names << t_name
        end

        @aliases.each do |n, target|
          raise ValidationError.new(group_alias_conflict(n), @name) if used_group_names.include?(n)
          if used_target_names.include?(n)
            raise ValidationError.new(alias_target_conflict(n), @name)
          end

          if used_aliases.include?(n)
            raise ValidationError.new(alias_conflict(n, target, used_aliases[n]), @name)
          end

          used_aliases[n] = target
        end

        @groups.each do |g|
          g.validate(used_group_names, used_target_names, used_aliases)
        rescue ValidationError => e
          e.add_parent(@name)
          raise e
        end

        nil
      end

      def resolve_data_keys(data, target = nil)
        result = {
          'config' => @plugins.resolve_references(data.fetch('config', {})),
          'vars' => @plugins.resolve_references(data.fetch('vars', {})),
          'facts' => @plugins.resolve_references(data.fetch('facts', {})),
          'features' => @plugins.resolve_references(data.fetch('features', [])),
          'plugin_hooks' => @plugins.resolve_references(data.fetch('plugin_hooks', {}))
        }
        validate_data_keys(result, target)
        result['features'] = Set.new(result['features'].flatten)
        result
      end

      def validate_data_keys(data, target = nil)
        {
          'config' => Hash,
          'vars' => Hash,
          'facts' => Hash,
          'features' => Array,
          'plugin_hooks' => Hash
        }.each do |key, expected_type|
          next if !data.key?(key) || data[key].is_a?(expected_type) || @plugins.reference?(data[key])

          msg = +"Expected #{key} to be of type #{expected_type}, not #{data[key].class}"
          msg << " for target #{target}" if target
          raise ValidationError.new(msg, @name)
        end
        unless @plugins.reference?(data['config'])
          unexpected_keys = data.fetch('config', {}).keys - CONFIG_KEYS
          if unexpected_keys.any?
            msg = +"Found unexpected key(s) #{unexpected_keys.join(', ')} in config for"
            msg << " target #{target} in" if target
            msg << " group #{@name}"
            @logger.warn(msg)
          end
        end
      end

      def group_data
        @group_data ||= resolve_data_keys(@input).merge('groups' => [@name])
      end

      # Returns targets contained directly within the group, ignoring subgroups
      def local_targets
        Set.new(@unresolved_targets.keys) + Set.new(@resolved_targets.keys)
      end

      def contains_target?(target_name)
        @unresolved_targets.key?(target_name) || @resolved_targets.key?(target_name)
      end

      # Returns all targets contained within the group, which includes targets from subgroups.
      def all_targets
        @groups.inject(local_targets) do |acc, g|
          acc.merge(g.all_targets)
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

      def target_collect(target_name)
        child_data = @groups.map { |group| group.target_collect(target_name) }
        # Data from earlier groups wins
        child_result = child_data.inject do |acc, group_data|
          data_merge(group_data, acc)
        end
        # Children override the parent
        data_merge(target_data(target_name), child_result)
      end

      def group_collect(target_name)
        child_data = @groups.map { |group| group.group_collect(target_name) }
        # Data from earlier groups wins
        child_result = child_data.inject do |acc, group_data|
          data_merge(group_data, acc)
        end

        # If this group has the target or one of the child groups has the
        # target, return the data, otherwise return nil
        if child_result || contains_target?(target_name)
          # Children override the parent
          data_merge(group_data, child_result)
        end
      end
    end
  end
end
