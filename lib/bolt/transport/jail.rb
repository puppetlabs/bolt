# frozen_string_literal: true

require_relative '../../bolt/transport/simple'

module Bolt
  module Transport
    class Jail < Simple
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

require_relative 'jail/connection'
