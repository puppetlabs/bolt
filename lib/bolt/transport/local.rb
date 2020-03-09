# frozen_string_literal: true

require 'bolt/transport/simple'

module Bolt
  module Transport
    class Local < Simple
      def connected?(_target)
        true
      end

      def with_connection(target)
        yield Connection.new(target)
      end
    end
  end
end

require 'bolt/transport/local/connection'
