# frozen_string_literal: true

require 'set'
require 'bolt/config'
require 'bolt/inventory/group'
require 'bolt/inventory/inventory'
require 'bolt/inventory/options'
require 'bolt/target'
require 'bolt/util'
require 'bolt/plugin'
require 'bolt/validator'
require 'yaml'

module Bolt
  class Inventory
    include Bolt::Inventory::Options

    ENVIRONMENT_VAR = 'BOLT_INVENTORY'

    class ValidationError < Bolt::Error
      attr_accessor :path

      def initialize(message, offending_group)
        super(message, 'bolt.inventory/validation-error')
        @_message = message
        @path = [offending_group].compact
      end

      def details
        { 'path' => path }
      end

      def add_parent(parent_group)
        @path << parent_group
      end

      def message
        if path.empty?
          @_message
        else
          "#{@_message} for group at #{path}"
        end
      end
    end

    class WildcardError < Bolt::Error
      def initialize(target)
        super("Found 0 nodes matching wildcard pattern #{target}", 'bolt.inventory/wildcard-error')
      end
    end

    # Builds the schema used by the validator.
    #
    def self.schema
      schema = {
        type:        Hash,
        properties:  OPTIONS.map { |opt| [opt, _ref: opt] }.to_h,
        definitions: DEFINITIONS,
        _plugin:     true
      }

      schema[:definitions]['config'][:properties] = Bolt::Config.transport_definitions
      schema
    end

    def self.from_config(config, plugins)
      logger = Bolt::Logger.logger(self)

      if ENV.include?(ENVIRONMENT_VAR)
        begin
          source = ENVIRONMENT_VAR
          data = YAML.safe_load(ENV[ENVIRONMENT_VAR])
          raise Bolt::ParseError, "Could not parse inventory from $#{ENVIRONMENT_VAR}" unless data.is_a?(Hash)
          logger.debug("Loaded inventory from environment variable #{ENVIRONMENT_VAR}")
        rescue Psych::Exception
          raise Bolt::ParseError, "Could not parse inventory from $#{ENVIRONMENT_VAR}"
        end
      elsif config.inventoryfile
        source = config.inventoryfile
        data = Bolt::Util.read_yaml_hash(config.inventoryfile, 'inventory')
        logger.debug("Loaded inventory from #{config.inventoryfile}")
      else
        source = config.default_inventoryfile
        data = Bolt::Util.read_optional_yaml_hash(config.default_inventoryfile, 'inventory')

        if config.default_inventoryfile.exist?
          logger.debug("Loaded inventory from #{config.default_inventoryfile}")
        else
          logger.debug("Tried to load inventory from #{config.default_inventoryfile}, but the file does not exist")
        end
      end

      # Resolve plugin references from transport config
      config.transports.each_value do |t|
        t.resolve(plugins) unless t.resolved?
      end

      Bolt::Validator.new.tap do |validator|
        validator.validate(data, schema, source)
        validator.warnings.each { |warning| logger.warn(warning) }
      end

      inventory = create_version(data, config.transport, config.transports, plugins)
      inventory.validate
      inventory
    end

    def self.create_version(data, transport, transports, plugins)
      version = (data || {}).delete('version') { 2 }

      case version
      when 2
        Bolt::Inventory::Inventory.new(data, transport, transports, plugins)
      else
        raise ValidationError.new("Unsupported version #{version} specified in inventory", nil)
      end
    end

    def self.empty
      config  = Bolt::Config.default
      plugins = Bolt::Plugin.setup(config, nil)

      create_version({}, config.transport, config.transports, plugins)
    end
  end
end
