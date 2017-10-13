module Bolt
  class NodeURI
    def initialize(string)
      @uri = parse(string)
    end

    def parse(string)
      uri = if string =~ %r{^(ssh|winrm|pcp)://}
              Addressable::URI.parse(string)
            else
              Addressable::URI.parse("ssh://#{string}")
            end
      uri.port ||= 5985 if uri.scheme == 'winrm'
      uri
    end

    def hostname
      @uri.hostname
    end

    def port
      @uri.port
    end

    def user
      @uri.user
    end

    def password
      @uri.password
    end

    def scheme
      @uri.scheme
    end
  end
end
