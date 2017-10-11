module Bolt
  class Node
    class BaseError < StandardError
      attr_reader :issue_code

      def initialize(message, issue_code)
        super(message)
        @issue_code = issue_code
      end

      def kind
        'puppetlabs.tasks/node-error'
      end
    end

    class ConnectError < BaseError
      def kind
        'puppetlabs.tasks/connect-error'
      end
    end
  end
end
