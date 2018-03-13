require 'set'
require 'bolt/util'
require 'bolt/target'
require 'bolt/inventory/group'

module Bolt
  class Inventory
    ENVIRONMENT_VAR = 'BOLT_INVENTORY'.freeze

    class ValidationError < Bolt::Error
      attr_accessor :path
      def initialize(message, offending_group)
        super(msg, 'bolt.inventory/validation-error')
        @_message = message
        @path = offending_group ? [offending_group] : []
      end

      def details
        { 'path' => path }
      end

      def add_parent(parent_group)
        @path << parent_group
      end

      def message
        "#{@_message} for group at #{path}"
      end
    end

    class WildcardError < Bolt::Error
      def initialize(target)
        super("Found 0 nodes matching wildcard pattern #{target}", 'bolt.inventory/wildcard-error')
      end
    end

    def self.default_paths
      [File.expand_path(File.join('~', '.puppetlabs', 'bolt', 'inventory.yaml'))]
    end

    def self.from_config(config)
      if ENV.include?(ENVIRONMENT_VAR)
        begin
          # rubocop:disable YAMLLoad
          data = YAML.load(ENV[ENVIRONMENT_VAR])
        # In older releases of psych SyntaxError is not a subclass of Exception
        rescue Psych::SyntaxError
          raise Bolt::CLIError, "Could not parse inventory from $#{ENVIRONMENT_VAR}"
        rescue Psych::Exception
          raise Bolt::CLIError, "Could not parse inventory from $#{ENVIRONMENT_VAR}"
        end
      else
        data = Bolt::Util.read_config_file(config[:inventoryfile], default_paths, 'inventory')
      end

      inventory = new(data, config)
      inventory.validate
      inventory.collect_groups
      inventory.add_localhost
      inventory
    end

    def initialize(data, config = nil)
      @logger = Logging.logger[self]
      # Config is saved to add config options to targets
      @config = config || Bolt::Config.new
      @data = data ||= {}
      @groups = Group.new(data.merge('name' => 'all'))
      @group_lookup = {}
      @target_vars = {}
    end

    def validate
      @groups.validate
    end

    def collect_groups
      # Provide a lookup map for finding a group by name
      @group_lookup = @groups.collect_groups
    end

    def add_localhost
      # Append a 'localhost' group if not already present.
      unless @group_lookup.include?('localhost') || @groups.node_names.include?('localhost')
        @groups.nodes['localhost'] = {
          'name' => 'localhost',
          'config' => { 'transport' => 'local' }
        }
      end
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

    def set_var(target, key, value)
      data = { key => value }
      set_vars_from_hash(target.name, data)
    end

    def vars(target)
      @target_vars[target.name]
    end

    #### PRIVATE ####
    #
    # For debugging only now
    def groups_in(node_name)
      @groups.data_for(node_name)['groups'] || {}
    end
    private :groups_in

    # Pass a target to get_targets for a public version of this
    # Should this reconfigure configured targets?
    def update_target(target)
      data = @groups.data_for(target.name) || {}

      unless data['config']
        @logger.debug("Did not find #{target.name} in inventory")
        data['config'] = {}
      end

      unless data['vars']
        @logger.debug("Did not find any variables for #{target.name} in inventory")
        data['vars'] = {}
      end

      set_vars_from_hash(target.name, data['vars'])

      # Use Config object to ensure config section is treated consistently with config file
      conf = @config.deep_clone
      conf.update_from_inventory(data['config'])
      conf.validate

      target.update_conf(conf.transport_conf)
    end
    private :update_target

    # If target is a group name, expand it to the members of that group.
    # If a wildcard string, match against nodes in inventory (or error if none found).
    # Else return [target].
    def resolve_name(target)
      if (group = @group_lookup[target])
        group.node_names
      elsif target.include?('*')
        # Try to wildcard match nodes in inventory
        # Ignore case because hostnames are generally case-insensitive
        regexp = Regexp.new("^#{Regexp.escape(target).gsub('\*', '.*?')}$", Regexp::IGNORECASE)

        nodes = []
        @groups.node_names.each do |node|
          if node =~ regexp
            nodes << node
          end
        end

        raise(WildcardError, target) if nodes.empty?
        nodes
      else
        [target]
      end
    end
    private :resolve_name

    def expand_targets(targets)
      if targets.is_a? Bolt::Target
        targets
      elsif targets.is_a? Array
        targets.map { |tish| expand_targets(tish) }
      elsif targets.is_a? String
        # Expand a comma-separated list
        targets.split(/[[:space:],]+/).reject(&:empty?).map do |name|
          ts = resolve_name(name)
          ts.map { |t| Bolt::Target.new(t) }
        end
      end
    end
    private :expand_targets

    def set_vars_from_hash(target_name, data)
      if data
        # Instantiate empty vars hash in case no vars are defined
        @target_vars[target_name] = @target_vars[target_name] || {}
        # Assign target new merged vars hash
        # This is essentially a copy-on-write to maintain the immutability of @target_vars
        @target_vars[target_name] = @target_vars[target_name].merge(data).freeze
      end
    end
    private :set_vars_from_hash
  end
end
