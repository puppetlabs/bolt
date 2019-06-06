# frozen_string_literal: true

require 'bolt/plugin/puppetdb'
require 'bolt/plugin/terraform'
require 'bolt/plugin/prompt'

module Bolt
  class Plugin
    def self.setup(config, pdb_client)
      plugins = new(config)
      plugins.add_plugin(Bolt::Plugin::Puppetdb.new(pdb_client))
      plugins.add_plugin(Bolt::Plugin::Terraform.new)
      plugins.add_plugin(Bolt::Plugin::Prompt)
      plugins
    end

    def initialize(_config)
      @plugins = {}
    end

    def add_plugin(plugin)
      @plugins[plugin.name] = plugin
    end

    def for_hook(hook)
      @plugins.filter { |_n, plug| plug.hooks.include? hook }
    end

    def by_name(plugin_name)
      @plugins[plugin_name]
    end
  end
end
