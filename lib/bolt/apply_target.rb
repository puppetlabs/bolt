# frozen_string_literal: true

module Bolt
  class ApplyTarget
    ATTRIBUTES = %i[uri name target_alias config vars facts features
                    plugin_hooks resources safe_name].freeze
    COMPUTED = %i[host password port protocol user].freeze

    attr_reader(*ATTRIBUTES)
    attr_accessor(*COMPUTED)

    # rubocop:disable Lint/UnusedMethodArgument
    # Target.new from a plan initialized with a hash
    def self.from_asserted_hash(hash)
      raise Bolt::Error.new("Target objects cannot be instantiated inside apply blocks", 'bolt/apply-error')
    end

    # Target.new from a plan with just a uri.
    def self.from_asserted_args(uri = nil,
                                name = nil,
                                safe_name = nil,
                                target_alias = nil,
                                config = nil,
                                facts = nil,
                                vars = nil,
                                features = nil,
                                plugin_hooks = nil,
                                resources = nil)
      raise Bolt::Error.new("Target objects cannot be instantiated inside apply blocks", 'bolt/apply-error')
    end
    # rubocop:enable Lint/UnusedMethodArgument

    def self._pcore_init_from_hash
      raise "ApplyTarget shouldn't be instantiated from a pcore_init class method. How did this get called?"
    end

    def _pcore_init_from_hash(init_hash)
      inventory = Puppet.lookup(:bolt_inventory)
      initialize(init_hash, inventory.config_hash)
      inventory.create_apply_target(self)
      self
    end

    def initialize(target_hash, config)
      ATTRIBUTES.each do |attr|
        instance_variable_set("@#{attr}", target_hash[attr.to_s])
      end

      # Merge the config hash with inventory config
      config = Bolt::Util.deep_merge(config, @config || {})
      transport = config['transport'] || 'ssh'
      t_conf = config['transports'][transport] || {}
      uri_obj = parse_uri(uri)
      @host = uri_obj.hostname || t_conf['host']
      @password = Addressable::URI.unencode_component(uri_obj.password) || t_conf['password']
      @port = uri_obj.port || t_conf['port']
      @protocol = uri_obj.scheme || transport
      @user = Addressable::URI.unencode_component(uri_obj.user) || t_conf['user']
    end

    def to_s
      @safe_name
    end

    def parse_uri(string)
      require 'addressable/uri'
      if string.nil?
        Addressable::URI.new
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

    def hash
      @name.hash
    end
  end
end
