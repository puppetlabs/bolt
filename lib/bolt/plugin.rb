# frozen_string_literal: true

require 'bolt/plugin/puppetdb'
require 'bolt/plugin/terraform'
require 'bolt/plugin/pkcs7'
require 'bolt/plugin/prompt'
require 'bolt/plugin/task'
require 'bolt/plugin/aws'
require 'bolt/plugin/vault'

module Bolt
  class Plugin
    class PluginError < Bolt::Error
      class ExecutionError < PluginError
        def initialize(msg, plugin_name, location)
          mess = "Error executing plugin: #{plugin_name} from #{location}: #{msg}"
          super(mess, 'bolt/plugin-error')
        end
      end

      class Unknown < PluginError
        def initialize(plugin_name)
          super("Unknown plugin: '#{plugin_name}'", 'bolt/unknown-plugin')
        end
      end

      class UnsupportedHook < PluginError
        def initialize(plugin_name, hook)
          super("Plugin #{plugin_name} does not support #{hook}", 'bolt/unsupported-hook')
        end
      end
    end

    def self.setup(config, pdb_client, analytics)
      plugins = new(config, analytics)
      plugins.add_plugin(Bolt::Plugin::Puppetdb.new(pdb_client))
      plugins.add_plugin(Bolt::Plugin::Terraform.new)
      plugins.add_plugin(Bolt::Plugin::Prompt.new)
      plugins.add_plugin(Bolt::Plugin::Pkcs7.new(config.boltdir.path, config.plugins['pkcs7'] || {}))
      plugins.add_plugin(Bolt::Plugin::Task.new(config))
      plugins.add_plugin(Bolt::Plugin::Aws::EC2.new(config.plugins['aws'] || {}))
      plugins.add_plugin(Bolt::Plugin::Vault.new(config.plugins['vault'] || {}))
      plugins
    end

    def initialize(config, analytics)
      @config = config
      @analytics = analytics
      @plugins = {}
    end

    def add_plugin(plugin)
      @plugins[plugin.name] = plugin
    end

    def get_hook(plugin_name, hook)
      plugin = by_name(plugin_name)
      raise PluginError::Unknown, plugin_name unless plugin
      raise PluginError::UnsupportedHook.new(plugin_name, hook) unless plugin.respond_to?(hook)
      @analytics.report_bundled_content("Plugin #{hook}", plugin_name)

      plugin.method(hook)
    end

    def by_name(plugin_name)
      @plugins[plugin_name]
    end
  end
end
