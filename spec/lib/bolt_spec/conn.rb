# frozen_string_literal: true

require 'bolt/util'
require 'bolt/inventory'

module BoltSpec
  module Conn
    def conn_info(transport)
      default_host        = 'localhost'
      default_user        = 'bolt'
      default_password    = 'bolt'
      default_second_user = 'test'
      default_second_pw   = 'test'
      default_key         = File.expand_path(File.join(__dir__, '..', '..', 'fixtures/keys/id_rsa'))
      default_port        = 0
      additional_config   = {}

      tu = transport.upcase
      case transport
      when 'ssh'
        default_port = 20022
      when 'winrm'
        default_port      = 25985
        additional_config = { ssl: false,
                              'connect-timeout': 45 }
      when 'docker', 'podman'
        default_user     = ''
        default_password = ''
        default_host     = 'ubuntu_node'
      when 'lxd'
        default_host     = 'testlxd'
      else
        raise Error, "The transport must be either 'ssh', 'winrm', 'docker', 'podman', or 'lxd'."
      end

      additional_config.merge(
        protocol:    transport,
        host:        ENV["BOLT_#{tu}_HOST"] || default_host,
        user:        ENV["BOLT_#{tu}_USER"] || default_user,
        password:    ENV["BOLT_#{tu}_PASSWORD"] || default_password,
        port:        (ENV["BOLT_#{tu}_PORT"] || default_port).to_i,
        key:         ENV["BOLT_#{tu}_KEY"] || default_key,
        second_user: ENV["BOLT_#{tu}_SECOND_USER"] || default_second_user,
        second_pw:   ENV["BOLT_#{tu}_SECOND_PW"] || default_second_pw,
        system_user: `whoami`.strip
      )
    end

    def conn_uri(transport, include_password: false, override_port: nil)
      conn = conn_info(transport)
      passwd = include_password ? ":#{conn[:password]}" : ''
      port = ":#{override_port || conn[:port]}"
      "#{conn[:protocol]}://#{conn[:user]}#{passwd}@#{conn[:host]}#{port}"
    end

    def conn_target(transport, include_password: false, options: nil)
      inventory = Bolt::Inventory.empty
      target = inventory.get_target(conn_uri(transport, include_password: include_password))
      inventory.set_config(target, transport, options) if options
      target
    end

    def conn_inventory
      groups = %w[ssh winrm].map do |transport|
        { "name" => transport,
          "targets" => [conn_uri(transport)],
          "config" => {
            transport => Bolt::Util.walk_keys(conn_info(transport), &:to_s)
          } }
      end
      { "groups" => groups }
    end

    def docker_inventory(root: false)
      usernamepassword = root ? 'root' : 'bolt'
      {
        'groups' => [
          {
            'name' => 'ssh',
            'targets' => [
              {
                'name' => 'ubuntu_node',
                'alias' => 'agentless',
                'config' => { 'ssh' => { 'port' => 20022 } }
              }
            ],
            'groups' => [
              {
                'name' => 'nix_agents',
                'targets' => [
                  {
                    'name' => 'puppet_6_node',
                    'config' => { 'ssh' => { 'port' => 20024 } }
                  },
                  {
                    'name' => 'puppet_7_node',
                    'config' => { 'ssh' => { 'port' => 20025 } }
                  }
                ]
              }
            ],
            'config' => {
              'ssh' => {
                'host' => 'localhost',
                'host-key-check' => false,
                'user' => usernamepassword,
                'password' => usernamepassword
              }
            }
          }
        ]
      }
    end

    def root_password
      'root'
    end
  end
end
