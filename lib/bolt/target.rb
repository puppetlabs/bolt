# frozen_string_literal: true

require 'bolt/error'
require 'bolt/util'

module Bolt
  class Target2
    attr_accessor :inventory

    # Target.new from a plan initialized with a hash
    def self.from_asserted_hash(hash)
      inventory = Puppet.lookup(:bolt_inventory)
      inventory.create_target_from_plan(hash)
    end

    # Target.new from a plan with just a uri
    # rubocop:disable UnusedMethodArgument
    def self.from_asserted_args(uri = nil,
                                name = nil,
                                target_alias = nil,
                                config = nil,
                                facts = nil,
                                vars = nil,
                                features = nil,
                                plugin_hooks = nil)
      inventory = Puppet.lookup(:bolt_inventory)
      inventory.create_target_from_plan('uri' => uri)
    end

    # URI can be passes as nil
    def initialize(uri = nil,
                   name = nil,
                   target_alias = nil,
                   config = nil,
                   facts = nil,
                   vars = nil,
                   features = nil,
                   plugin_hooks = nil)
      @name = name
    end
    # rubocop:enable UnusedMethodArgument

    # Used for munging target + group data
    def target_data_hash
      {
        'config' => @inventory.targets[@name]['config'],
        'vars' => @inventory.targets[@name]['vars'],
        'facts' => @inventory.targets[@name]['facts'],
        'features' => @inventory.targets[@name]['features'].to_a,
        'plugin_hooks' => @inventory.targets[@name]['plugin_hooks'],
        'name' => @inventory.targets[@name]['name'],
        'uri' => @inventory.targets[@name]['uri'],
        'alias' => @inventory.targets[@name]['target_alias']
      }
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
      @inventory.target_config(self)
    end

    def safe_name
      @inventory.targets[@name]['safe_name']
    end

    def target_alias
      @inventory.targets[@name]['target_alias']
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

    def host
      @inventory.targets[@name]['uri_obj']&.hostname || @inventory.targets[@name]['host']
    end

    attr_reader :name

    def uri
      @inventory.targets[@name]['uri']
    end

    def remote?
      @inventory.targets[@name]['uri_obj']&.scheme == 'remote' || @inventory.targets[@name]['protocol'] == 'remote'
    end

    def port
      @inventory.targets[@name]['uri_obj']&.port || @inventory.targets[@name]['port']
    end

    # transport is separate from protocol for remote targets.
    def transport
      remote? ? 'remote' : protocol
    end

    def protocol
      @inventory.targets[@name]['uri_obj']&.scheme || @inventory.targets[@name]['protocol']
    end

    def user
      unencode(@inventory.targets[@name]['uri_obj']&.user) || @inventory.targets[@name]['user']
    end

    def password
      unencode(@inventory.targets[@name]['uri_obj']&.password) || @inventory.targets[@name]['password']
    end

    def options
      @inventory.targets[@name]['options']
    end

    def plugin_hooks
      @inventory.targets[@name]['cached_state']['plugin_hooks']
    end

    def unencode(component)
      Addressable::URI.unencode_component(component)
    end
    private :unencode
  end

  class Target
    attr_reader :options
    # CODEREVIEW: this feels wrong. The altertative is threading inventory through the
    # executor to the RemoteTransport
    attr_accessor :uri, :inventory

    PRINT_OPTS ||= %w[host user port protocol].freeze

    # Satisfies the Puppet datatypes API
    def self.from_asserted_hash(hash)
      new(hash['uri'], hash['options'])
    end

    # URI can be passes as nil
    def initialize(uri, options = nil)
      # lazy-load expensive gem code
      require 'addressable/uri'

      @uri = uri
      @uri_obj = parse(uri)
      @options = options || {}
      @options.freeze

      if @options['user']
        @user = @options['user']
      end

      if @options['password']
        @password = @options['password']
      end

      if @options['port']
        @port = @options['port']
      end

      if @options['protocol']
        @protocol = @options['protocol']
      end

      if @options['host']
        @host = @options['host']
      end

      # WARNING: name should never be updated
      @name = @options['name'] || @uri
    end

    def update_conf(conf)
      @protocol = conf[:transport]

      t_conf = conf[:transports][transport.to_sym] || {}
      # Override url methods
      @user = t_conf['user']
      @password = t_conf['password']
      @port = t_conf['port']
      @host = t_conf['host']

      # Preserve everything in options so we can easily create copies of a Target.
      @options = t_conf.merge(@options)

      self
    end

    def parse(string)
      if string.nil?
        nil
      elsif string =~ %r{^[^:]+://}
        Addressable::URI.parse(string)
      else
        # Initialize with an empty scheme to ensure we parse the hostname correctly
        Addressable::URI.parse("//#{string}")
      end
    rescue Addressable::URI::InvalidURIError => e
      raise Bolt::ParseError, "Could not parse target URI: #{e.message}"
    end
    private :parse

    def features
      if @inventory
        @inventory.features(self)
      else
        Set.new
      end
    end
    alias feature_set features

    def plugin_hooks
      if @inventory
        @inventory.plugin_hooks(self)
      else
        {}
      end
    end

    # TODO: WHAT does equality mean here?
    # should we just compare names? is there something else that is meaninful?
    def eql?(other)
      if self.class.equal?(other.class)
        if @uri
          return @uri == other.uri
        else
          @name = other.name
        end
      end
      false
    end
    alias == eql?

    def hash
      @uri.hash ^ @options.hash
    end

    def to_s
      opts = @options.select { |k, _| PRINT_OPTS.include? k }
      "Target('#{@uri}', #{opts})"
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

    def host
      @uri_obj&.hostname || @host
    end

    def name
      @name || @uri
    end

    def remote?
      @uri_obj&.scheme == 'remote' || @protocol == 'remote'
    end

    def port
      @uri_obj&.port || @port
    end

    # transport is separate from protocol for remote targets.
    def transport
      remote? ? 'remote' : protocol
    end

    def protocol
      @uri_obj&.scheme || @protocol
    end

    def user
      Addressable::URI.unencode_component(@uri_obj&.user) || @user
    end

    def password
      Addressable::URI.unencode_component(@uri_obj&.password) || @password
    end
  end
end
