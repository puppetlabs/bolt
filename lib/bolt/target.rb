require 'addressable/uri'
require 'bolt/error'

module Bolt
  class Target
    attr_reader :uri, :options

    # Satisfies the Puppet datatypes API
    def self.from_asserted_hash(hash)
      new(hash['uri'], hash['options'])
    end

    def self.from_uri(uri)
      new(uri)
    end

    def self.parse_urls(urls)
      urls.split(/[[:space:],]+/).reject(&:empty?).uniq.map { |url| from_uri(url) }
    end

    def initialize(uri, options = nil)
      @uri = uri
      @uri_obj = parse(uri)
      @options = options || {}
    end

    def parse(string)
      if string =~ %r{^[^:]+://}
        Addressable::URI.parse(string)
      else
        # Initialize with an empty scheme to ensure we parse the hostname correctly
        Addressable::URI.parse("//#{string}")
      end
    end
    private :parse

    def eql?(other)
      self.class.equal?(other.class) && @uri == other.uri && @options == other.options
    end
    alias == eql?

    def hash
      @uri.hash ^ @options.hash
    end

    def to_s
      "Target('#{@uri}', #{@options})"
    end

    def host
      @uri_obj.hostname
    end

    def port
      @uri_obj.port
    end

    # name is currently just uri but should be be used instead to identify the
    # Target ouside the transport or uri options.
    def name
      uri
    end

    def user
      Addressable::URI.unencode_component(
        @uri_obj.user
      )
    end

    def password
      Addressable::URI.unencode_component(
        @uri_obj.password
      )
    end

    def protocol
      @uri_obj.scheme
    end
  end
end
