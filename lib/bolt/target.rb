# frozen_string_literal: true

require 'bolt/error'

module Bolt
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
