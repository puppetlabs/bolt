# frozen_string_literal: true

require 'bolt/inventory/group2'

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
        @groups.resolve_aliases(@groups.target_aliases, @groups.target_names)
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
        @groups.target_names
      end
      # alias for analytics
      alias node_names target_names

      def get_targets(targets)
        flat_target_list(targets).map { |t| update_target(t) }
      end

      def get_target(target)
        target_array = flat_target_list(target)
        if target_array.count > 1
          raise ValidationError.new("'#{target}' refers to #{target_array.count} targets", nil)
        end
        get_targets(target_array.first).first
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
            # We should raise any error from the delay now
            val.value!
          else
            val
          end
        end
      end
      private :config_plugin

      # Pass a target to get_targets for a public version of this
      def update_target(target)
        # Ensure all targets in inventory are included in the all group.
        unless @groups.target_names.include?(target.name)
          add_to_group([target], 'all')
        end

        # Get merged data between targets and groups
        data = @groups.data_for(target.name)
        data ||= {}

        unless data['config']
          @logger.debug("Did not find config for #{target.name} in inventory")
          data['config'] = {}
        end

        # Add defaults for special 'localhost' target (currently just config and features)
        if target.name == 'localhost'
          data = Bolt::Inventory.localhost_defaults(data)
        end

        # Data from inventory
        data['config'] = config_plugin(data['config'])
        # Data from set_config (make sure to resolve plugins)
        resolved_target_config = config_plugin(@targets[target.name]['config'] || {})
        data['config'] = Bolt::Util.deep_merge(data['config'], resolved_target_config)

        # Use Config object to ensure config section is treated consistently with config file
        conf = @config.deep_clone
        conf.update_from_inventory(data['config'])
        conf.validate

        # Recompute the target cached state with the merged data
        update_target_state(target, conf, data)

        unless target.transport.nil? || Bolt::TRANSPORTS.include?(target.transport.to_sym)
          raise Bolt::UnknownTransportError.new(target.transport, target.uri)
        end

        target
      end
      private :update_target

      # This algorithm for getting a flat list of targets is used several times.
      def flat_target_list(targets)
        target_array = expand_targets(targets)
        if target_array.is_a? Array
          target_array.flatten.uniq(&:name)
        else
          [target_array]
        end
      end
      private :flat_target_list

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
        if targets.is_a? Bolt::Target2
          targets
        elsif targets.is_a? Array
          targets.map { |tish| expand_targets(tish) }
        elsif targets.is_a? String
          # Expand a comma-separated list
          targets.split(/[[:space:],]+/).reject(&:empty?).map do |name|
            ts = resolve_name(name)
            ts.map do |t|
              # If the target exists, return it, otherwise create one
              @targets[t] ? @targets[t]['self'] : create_target(t)
            end
          end
        end
      end
      private :expand_targets

      def add_target(current_group, target, desired_group)
        if current_group.name == desired_group
          current_group.add_target(target.target_data_hash)
          @groups.validate
          update_target(target)
          return true
        end
        # Recurse on children Groups if not desired_group
        current_group.groups.each do |child_group|
          add_target(child_group, target, desired_group)
        end
      end
      private :add_target

      # This is effectively the init method for Target2
      def create_target(target_name, target_hash = nil)
        # Prefer target hash, then data from inventoryfile, allow for uri only with empty hash
        data = target_hash || @groups.target_collect(target_name) || {}
        data = { 'uri' => target_name } if data['uri'].nil? && data['name'].nil?
        data['uri_obj'] = Bolt::Inventory::Inventory2.parse_uri(data['uri'])

        if data['uri'] && data['name'].nil?
          data['name'] = data['uri']
          data['safe_name'] = data['uri_obj'].omit(:password).to_str.sub(%r{^//}, '')
        elsif data['name']
          data['safe_name'] = data['name']
        else
          data['name'] = target_name
          data['safe_name'] = if data['uri_obj']
                                data['uri_obj'].omit(:password).to_str.sub(%r{^//}, '')
                              else
                                target_name
                              end
        end
        unless data['name'].ascii_only?
          raise ValidationError.new("Target name must be ASCII characters: #{data['name']}", nil)
        end
        # Data set on target itself (either in inventory, target.new or with set_config)
        data['config'] ||= {}
        data['vars'] ||= {}
        data['facts'] ||= {}
        data['features'] = data['features'] ? Set.new(data['features']) : Set.new
        data['groups'] ||= []
        data['options'] ||= {}
        data['plugin_hooks'] ||= {}
        data['target_alias'] ||= []

        # Every call to update_target will rebuild this state based on merging together target, group, and config data
        data['cached_state'] = {}

        target = Target2.new(nil, data['name'])
        target.inventory = self
        data['self'] = target
        @targets[data['name']] = data
        target
      end
      private :create_target

      def create_target_from_plan(data)
        t_name = data['name'] || data['uri']

        # If target already exists, delete old and replace with new, otherwise add to new to all group
        if @targets[t_name]
          @targets.delete(t_name)
          t = create_target(t_name, data)
          update_target(t)
        else
          t = create_target(t_name, data)
          update_target(t)
          add_to_group([t], 'all')
        end
        t
      end

      def self.parse_uri(string)
        require 'addressable/uri'
        if string.nil?
          nil
        # Forbid empty uri
        elsif string.empty?
          raise Bolt::ParseError, "Could not parse target URI: URI is empty string"
        elsif string =~ %r{^[^:]+://}
          Addressable::URI.parse(string)
        else
          # Initialize with an empty scheme to ensure we parse the hostname correctly
          Addressable::URI.parse("//#{string}")
        end
      rescue Addressable::URI::InvalidURIError => e
        raise Bolt::ParseError, "Could not parse target URI: #{e.message}"
      end

      def set_var(target, var_hash)
        @targets[target.name]['vars'] = @targets[target.name]['vars'].merge(var_hash)
        update_target(target)
      end

      def vars(target)
        @targets[target.name]['cached_state']['vars'] || {}
      end

      def add_facts(target, new_facts = {})
        @targets[target.name]['facts'] = Bolt::Util.deep_merge(@targets[target.name]['facts'], new_facts)
        update_target(target)
        facts(target)
      end

      def facts(target)
        @targets[target.name]['cached_state']['facts'] || {}
      end

      def set_feature(target, feature, value = true)
        if value
          @targets[target.name]['features'] << feature
        else
          @targets[target.name]['features'].delete(feature)
        end
        update_target(target)
      end

      def features(target)
        if @targets[target.name]['cached_state']['features']
          Set.new(@targets[target.name]['cached_state']['features'])
        else
          Set.new
        end
      end

      def plugin_hooks(target)
        @targets[target.name]['cached_state']['plugin_hooks'] || {}
      end

      def set_config(target, key_or_key_path, value)
        config = key_or_key_path.empty? ? value : build_config_hash([key_or_key_path].flatten, value)
        @targets[target.name]['config'] = @targets[target.name]['config'].merge(config)
        update_target(target)
      end

      def target_config(target)
        @targets[target.name]['cached_state']['config'] || {}
      end

      def build_config_hash(key_or_key_path, value)
        # https://stackoverflow.com/questions/5095077/ruby-convert-array-to-nested-hash
        key_or_key_path.reverse.inject(value) { |acc, key| { key => acc } }
      end
      private :build_config_hash

      def update_target_state(target, conf, merged_data)
        @targets[target.name]['protocol'] = conf.transport_conf[:transport]
        t_conf = conf.transport_conf[:transports][target.transport.to_sym] || {}
        @targets[target.name]['user'] = t_conf['user']
        @targets[target.name]['password'] = t_conf['password']
        @targets[target.name]['port'] = t_conf['port']
        @targets[target.name]['host'] = t_conf['host']
        @targets[target.name]['options'] = t_conf

        @targets[target.name]['cached_state'] = merged_data

        target_facts = @targets[target.name]['facts'] || {}
        new_facts = merged_data['facts'] || {}
        @targets[target.name]['cached_state']['facts'] = Bolt::Util.deep_merge(new_facts, target_facts)

        target_vars = @targets[target.name]['vars'] || {}
        new_vars = merged_data['vars'] || {}
        @targets[target.name]['cached_state']['vars'] = new_vars.merge(target_vars)

        target_features = Set.new(@targets[target.name]['features'])
        new_features = Set.new(merged_data['features'])
        @targets[target.name]['cached_state']['features'] = new_features.merge(target_features)

        target_plugin_hooks = @targets[target.name]['plugin_hooks'] || {}
        new_plugin_hooks = merged_data['plugin_hooks'] || {}
        plugin_hooks_from_inv = new_plugin_hooks.merge(target_plugin_hooks)
        @targets[target.name]['cached_state']['plugin_hooks'] = conf.plugin_hooks.merge(plugin_hooks_from_inv)
      end
      private :update_target_state
    end
  end
end
