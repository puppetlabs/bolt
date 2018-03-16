# frozen_string_literal: true

require 'bolt/config'
require 'bolt_spec/conn'

module BoltSpec
  module Config
    def fixture_path(*parts)
      File.join(__dir__, '..', '..', 'fixtures', *parts)
    end

    def config(overrides = {})
      empty = {
        inventoryfile: fixture_path('inventory', 'empty.yml')
      }
      Bolt::Config.new(empty.merge(overrides))
    end

    def conn_config(overrides = {})
      conn = BoltSpec.conn.new
      conn_conf = {
        ssh: conn.conn_info('ssh'),
        winrm: conn.conn_info('winrm')
      }
      config(conn_conf.merge(overrides))
    end
  end
end
