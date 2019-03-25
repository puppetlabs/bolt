# frozen_string_literal: true

require 'bolt/error'

module Bolt
  class Target
    attr_reader :uri, :options
    # CODEREVIEW: this feels wrong. The altertative is threading inventory through the
    # executor to the RemoteTransport
    attr_accessor :inventory

    PRINT_OPTS ||= %w[host user port protocol].freeze

    # Satisfies the Puppet datatypes API
    def self.from_asserted_hash(hash)
      new(hash['uri'], hash['options'])
    end

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
    end

    def update_conf(conf)
      @protocol = conf[:transport]

      t_conf = conf[:transports][transport.to_sym] || {}
      # Override url methods
      @user = t_conf['user']
      @password = t_conf['password']
      @port = t_conf['port']

      # Preserve everything in options so we can easily create copies of a Target.
      @options = t_conf.merge(@options)

      self
    end

    def parse(string)
      if string =~ %r{^[^:]+://}
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

    def eql?(other)
      self.class.equal?(other.class) && @uri == other.uri
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
      @uri_obj.hostname
    end

    # name is currently just uri but should be used instead to identify the
    # Target ouside the transport or uri options.
    def name
      uri
    end

    def remote?
      @uri_obj.scheme == 'remote' || @protocol == 'remote'
    end

    def port
      @uri_obj.port || @port
    end

    # transport is separate from protocol for remote targets.
    def transport
      remote? ? 'remote' : protocol
    end

    def protocol
      @uri_obj.scheme || @protocol
    end

    def user
      Addressable::URI.unencode_component(@uri_obj.user) || @user
    end

    def password
      Addressable::URI.unencode_component(@uri_obj.password) || @password
    end
  end
end
