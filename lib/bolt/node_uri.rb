module Bolt
  class NodeURI
    def initialize(string)
      @uri = parse(string)
    end

    def parse(string)
      case string
      when %r{^(local|ssh|winrm|pcp)://.*:\d+$}
        URI(string)
      when %r{^pcp://}
        URI(string)
      when %r{^(local|ssh|winrm)://}
        uri = URI(string)
        uri.port = 5985 if uri.scheme == 'winrm'
        uri
      else
        URI("ssh://#{string}")
      end
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
