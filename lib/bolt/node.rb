module Bolt
  class Node
    def self.parse_uri(node)
      case node
      when %r{^(ssh|winrm)://.*:\d+$}
        URI(node)
      when %r{^(ssh|winrm)://}
        uri = URI(node)
        uri.port = uri.scheme == 'ssh' ? 22 : 5985
        uri
      when /.*:\d+$/
        URI("ssh://#{node}")
      else
        URI("ssh://#{node}:22")
      end
    end

    def self.from_uri(uri_string, user, password)
      uri = parse_uri(uri_string)
      klass = if uri.scheme == 'winrm'
                Bolt::WinRM
              else
                Bolt::SSH
              end
      klass.new(uri.host, uri.port, user, password)
    end
  end
end

require 'bolt/node/ssh'
require 'bolt/node/winrm'
