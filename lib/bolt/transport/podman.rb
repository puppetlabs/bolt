# frozen_string_literal: true

require 'json'
require 'shellwords'
require_relative '../../bolt/transport/base'

module Bolt
  module Transport
    class Podman < Docker
      def with_connection(target)
        conn = Connection.new(target)
        conn.connect
        yield conn
      end
    end
  end
end

require_relative 'podman/connection'
