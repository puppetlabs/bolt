# frozen_string_literal: true

require_relative '../../bolt/logger'
require_relative '../../bolt/transport/simple'

module Bolt
  module Transport
    class Local < Simple
      def connected?(_target)
        true
      end

      def with_connection(target)
        if target.transport_config['bundled-ruby']
          target.set_local_defaults
        end

        yield Connection.new(target)
      end
    end
  end
end

require_relative 'local/connection'
