# frozen_string_literal: true

module Bolt
  module Transport
    class Local < Sudoable
      def provided_features
        ['shell']
      end

      def with_connection(target, *_args)
        conn = Shell.new(target)
        yield conn
      end

      def connected?(_targets)
        true
      end
    end
  end
end

require 'bolt/transport/local/shell'
