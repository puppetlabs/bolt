# frozen_string_literal: true

require 'bolt/error'

module BoltServer
  class Plugin
    class PluginNotSupported < Bolt::Error
      def initialize(msg, plugin_name)
        super(msg, 'bolt/plugin-not-supported', { "plugin_name" => plugin_name })
      end
    end
  end
end
