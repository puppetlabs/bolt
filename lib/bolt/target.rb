require 'addressable/uri'
require 'bolt/error'

module Bolt
  class Target
    attr_reader :uri, :options

    # Satisfies the Puppet datatypes API
    def self.from_asserted_hash(hash)
      new(parse(hash['uri']), hash['options'])
    end

    def self.from_uri(uri)
      new(parse(uri))
    end

    def self.parse(string)
      if string =~ %r{^[^:]+://}
        Addressable::URI.parse(string)
      else
        # Initialize with an empty scheme to ensure we parse the hostname correctly
        Addressable::URI.parse("//#{string}")
      end
    end
    private_class_method :parse

    def self.parse_urls(urls)
      urls.split(/[[:space:],]+/).reject(&:empty?).uniq.map { |url| from_uri(url) }
    end

    def initialize(uri, options = {})
      @uri = uri
      @options = options
    end

    def eql?(other)
      self.class.equal?(other.class) && @uri == other.uri && @options == other.options
    end
    alias == eql?

    def hash
      @uri.hash ^ @options.hash
    end

    def to_s
      # Use Puppet::Pops::Types::StringConverter if it is available
      if Object.const_defined?(:Puppet) && Puppet.const_defined?(:Pops)
        Puppet::Pops::Types::StringConverter.singleton.convert(self)
      else
        "Target('#{@uri}', #{@options})"
      end
    end

    def host
      @uri.hostname.sub(%r{^/+}, '')
    end

    def port
      @uri.port
    end

    def user
      Addressable::URI.unencode_component(
        @uri.user
      )
    end

    def password
      Addressable::URI.unencode_component(
        @uri.password
      )
    end

    def protocol
      @uri.scheme
    end
  end
end
