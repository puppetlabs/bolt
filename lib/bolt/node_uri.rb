module Bolt
  class NodeURI
    def initialize(string)
      @uri = parse(string)
    end

    def parse(string)
      case string
      when %r{^(ssh|winrm)://.*:\d+$}
        URI(string)
      when %r{^(ssh|winrm)://}
        uri = URI(string)
        uri.port = uri.scheme == 'ssh' ? 22 : 5985
        uri
      when /.*:\d+$/
        URI("ssh://#{string}")
      else
        URI("ssh://#{string}:22")
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
