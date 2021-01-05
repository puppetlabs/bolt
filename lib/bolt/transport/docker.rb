# frozen_string_literal: true

require 'json'
require 'shellwords'
require 'bolt/transport/base'

module Bolt
  module Transport
    class Docker < Simple
      def provided_features
        ['shell']
      end

      def with_connection(target)
        conn = Connection.new(target)
        conn.connect
        yield conn
      end
    end
  end
end

require 'bolt/transport/docker/connection'
