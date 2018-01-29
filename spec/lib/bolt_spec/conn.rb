module BoltSpec
  module Conn
    def conn_info(transport)
      tu = transport.upcase
      default_port = case transport
                     when 'ssh'
                       20022
                     when 'winrm'
                       25985
                     end

      {
        protocol: transport,
        host: ENV["BOLT_#{tu}_HOST"] || "localhost",
        user: ENV["BOLT_#{tu}_USER"] || "vagrant",
        password: ENV["BOLT_#{tu}_PASSWORD"] || "vagrant",
        port: ENV["BOLT_#{tu}_PORT"] || default_port,
        key: ENV["BOLT_#{tu}_KEY"] || Dir[".vagrant/**/private_key"]
      }
    end

    def conn_uri(transport, include_password = false)
      conn = conn_info(transport)
      passwd = include_password ? ":#{conn[:password]}" : ''
      "#{conn[:protocol]}://#{conn[:user]}#{passwd}@#{conn[:host]}:#{conn[:port]}"
    end
  end
end
