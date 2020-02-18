# frozen_string_literal: true

require 'bolt/error'
require 'bolt/util'

module Bolt
  class Target
    attr_accessor :inventory

    # Target.new from a data hash
    def self.from_hash(hash, inventory)
      target = inventory.create_target_from_hash(hash)
      new(target.name, inventory)
    end

    # Target.new from a plan initialized with a hash
    def self.from_asserted_hash(hash)
      inventory = Puppet.lookup(:bolt_inventory)
      from_hash(hash, inventory)
    end

    # TODO: Disallow any positional argument other than URI.
    # Target.new from a plan with just a uri. Puppet requires the arguments to
    # this method to match (by name) the attributes defined on the datatype.
    # rubocop:disable Lint/UnusedMethodArgument
    def self.from_asserted_args(uri = nil,
                                name = nil,
                                safe_name = nil,
                                target_alias = nil,
                                config = nil,
                                facts = nil,
                                vars = nil,
                                features = nil,
                                plugin_hooks = nil)
      from_asserted_hash('uri' => uri)
    end
    # rubocop:enable Lint/UnusedMethodArgument

    def initialize(name, inventory = nil)
      @name = name
      @inventory = inventory
    end

    # features returns an array to be compatible with plans
    def features
      @inventory.features(self).to_a
    end

    # Use feature_set internally to access set
    def feature_set
      @inventory.features(self)
    end

    def vars
      @inventory.vars(self)
    end

    def facts
      @inventory.facts(self)
    end

    def to_s
      safe_name
    end

    def config
      inventory_target.config
    end

    def safe_name
      inventory_target.safe_name
    end

    def target_alias
      inventory_target.target_alias
    end

    def to_h
      options.merge(
        'name' => name,
        'uri' => uri,
        'protocol' => protocol,
        'user' => user,
        'password' => password,
        'host' => host,
        'port' => port
      )
    end

    def detail
      {
        'name' => name,
        'uri' => uri,
        'alias' => target_alias,
        'config' => Bolt::Util.deep_merge(config, 'transport' => transport, transport => options),
        'vars' => vars,
        'features' => features,
        'facts' => facts,
        'plugin_hooks' => plugin_hooks
      }
    end

    def inventory_target
      @inventory.targets[@name]
    end

    def host
      inventory_target.host
    end

    attr_reader :name

    def uri
      inventory_target.uri
    end

    def remote?
      protocol == 'remote'
    end

    def port
      inventory_target.port
    end

    def transport
      inventory_target.transport
    end

    def protocol
      inventory_target.protocol || inventory_target.transport
    end

    def user
      inventory_target.user
    end

    def password
      inventory_target.password
    end

    def options
      inventory_target.options
    end

    def plugin_hooks
      inventory_target.plugin_hooks
    end

    def eql?(other)
      self.class.equal?(other.class) && @name == other.name
    end
    alias == eql?
  end
end
