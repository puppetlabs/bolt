# frozen_string_literal: true

require 'bolt/logger'
require 'bolt/transport/simple'

module Bolt
  module Transport
    class Local < Simple
      def connected?(_target)
        true
      end

      def with_connection(target)
        if target.transport_config['bundled-ruby'] || target.name == 'localhost'
          target.set_local_defaults
        end

        if target.name != 'localhost' &&
           !target.transport_config.key?('bundled-ruby')
          msg = "The local transport will default to using Bolt's Ruby interpreter and "\
            "setting the 'puppet-agent' feature in Bolt 3.0. Enable or disable these "\
            "defaults by setting 'bundled-ruby' in the local transport config."
          Bolt::Logger.warn_once("local_default_config", msg)
        end

        yield Connection.new(target)
      end
    end
  end
end

require 'bolt/transport/local/connection'
