module Bolt
  class Target
    attr_reader :host, :options

    def self.from_asserted_hash(hash)
      new(hash['host'], hash['options'])
    end

    def initialize(host, options = {})
      @host = host
      @options = options
    end

    def eql?(other)
      self.class.equal?(other.class) && @host == other.host && @options == other.options
    end
    alias == eql?

    def hash
      @host.hash ^ @options.hash
    end

    def to_s
      # Use Puppet::Pops::Types::StringConverter if it is available
      if Object.const_defined?(:Puppet) && Puppet.const_defined?(:Pops)
        Puppet::Pops::Types::StringConverter.singleton.convert(self)
      else
        "Target('#{@host}', #{@options})"
      end
    end
  end
end
