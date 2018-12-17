# frozen_string_literal: true

require 'bolt/transport/api/connection'

# A copy of the orchestrator transport which uses the api connection class
# in order to bypass calling 'start_plan'
module Bolt
  module Transport
    class Api < Orch
      def initialize(*args)
        super
      end

      def get_connection(conn_opts)
        key = Bolt::Transport::Api::Connection.get_key(conn_opts)
        unless (conn = @connections[key])
          @connections[key] = Bolt::Transport::Api::Connection.new(conn_opts, logger)
          conn = @connections[key]
        end
        conn
      end

      def batches(targets)
        targets.group_by { |target| Bolt::Transport::Api::Connection.get_key(target.options) }.values
      end
    end
  end
end
