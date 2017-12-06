require 'addressable/uri'

module Bolt
  class NodeURI
    def initialize(string, transport = 'ssh')
      @uri = parse(string, transport)
    end

    def parse(string, transport)
      uri = if string =~ %r{^[^:]+://}
              Addressable::URI.parse(string)
            else
              Addressable::URI.parse("#{transport}://#{string}")
            end
      uri.port ||= 5985 if uri.scheme == 'winrm'
      uri
    end
    private :parse

    def hostname
      @uri.hostname
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

    def scheme
      @uri.scheme
    end
  end
end
