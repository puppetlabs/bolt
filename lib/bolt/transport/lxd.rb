# frozen_string_literal: true

require_relative '../../bolt/logger'
require_relative '../../bolt/node/errors'
require_relative '../../bolt/transport/simple'

module Bolt
  module Transport
    class LXD < Simple
      def provided_features
        ['shell']
      end

      def with_connection(target, options = {})
        Bolt::Logger.warn_once("lxd_experimental",
                               "The LXD transport is experimental, and might " \
                               "include breaking changes between minor versions.")
        conn = Connection.new(target, options)
        conn.connect
        yield conn
      end
    end
  end
end

require_relative 'lxd/connection'
