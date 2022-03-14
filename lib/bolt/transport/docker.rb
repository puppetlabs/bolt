# frozen_string_literal: true

require 'json'
require 'shellwords'
require_relative '../../bolt/transport/simple'

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

require_relative 'docker/connection'
