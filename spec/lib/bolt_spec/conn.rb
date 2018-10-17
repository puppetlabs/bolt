# frozen_string_literal: true

require 'bolt/util'

module BoltSpec
  module Conn
    def conn_info(transport)
      tu = transport.upcase
      case transport
      when 'ssh'
        default_port = 20022
        default_user = 'bolt'
        default_password = 'bolt'
        default_key = Dir["spec/fixtures/keys/id_rsa"]
      when 'winrm'
        default_port = 25985
        default_user = 'bolt'
        default_password = 'bolt'
        default_key = Dir["spec/fixtures/keys/id_rsa"]
      else
        raise Error, "The transport must be either 'ssh' or 'winrm'"
      end

      port = ENV["BOLT_#{tu}_PORT"] || default_port

      {
        protocol: transport,
        host: ENV["BOLT_#{tu}_HOST"] || "localhost",
        user: ENV["BOLT_#{tu}_USER"] || default_user,
        password: ENV["BOLT_#{tu}_PASSWORD"] || default_password,
        port: port.to_i,
        key: ENV["BOLT_#{tu}_KEY"] || default_key
      }
    end

    def conn_uri(transport, include_password: false, override_port: nil)
      conn = conn_info(transport)
      passwd = include_password ? ":#{conn[:password]}" : ''
      port = override_port || conn[:port]
      "#{conn[:protocol]}://#{conn[:user]}#{passwd}@#{conn[:host]}:#{port}"
    end

    def conn_target(transport, include_password: false, options: nil)
      Bolt::Target.new(conn_uri(transport, include_password: include_password), options)
    end

    def conn_inventory
      groups = %w[ssh winrm].map do |transport|
        { "name" => transport,
          "nodes" => [conn_uri(transport)],
          "config" => {
            transport => Bolt::Util.walk_keys(conn_info(transport), &:to_s)
          } }
      end
      { "groups" => groups }
    end
  end
end
