# frozen_string_literal: true

require 'bolt/util'

module BoltSpec
  module Conn
    def conn_info(transport)
      default_host = 'localhost'
      default_user = 'bolt'
      default_password = 'bolt'
      default_key = Dir["spec/fixtures/keys/id_rsa"][0]
      default_port = 0

      tu = transport.upcase
      case transport
      when 'ssh'
        default_port = 20022
      when 'winrm'
        default_port = 25985
      when 'docker'
        default_user = ''
        default_password = ''
        default_host = 'ubuntu_node'
      else
        raise Error, "The transport must be either 'ssh' or 'winrm'"
      end

      {
        protocol: transport,
        host: ENV["BOLT_#{tu}_HOST"] || default_host,
        user: ENV["BOLT_#{tu}_USER"] || default_user,
        password: ENV["BOLT_#{tu}_PASSWORD"] || default_password,
        port: (ENV["BOLT_#{tu}_PORT"] || default_port).to_i,
        key: ENV["BOLT_#{tu}_KEY"] || default_key
      }
    end

    def conn_uri(transport, include_password: false, override_port: nil)
      conn = conn_info(transport)
      passwd = include_password ? ":#{conn[:password]}" : ''
      port = ":#{override_port || conn[:port]}"
      "#{conn[:protocol]}://#{conn[:user]}#{passwd}@#{conn[:host]}#{port}"
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

    def root_password
      'root'
    end
  end
end
