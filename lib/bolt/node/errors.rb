# frozen_string_literal: true

require 'bolt/error'

module Bolt
  class Node
    class BaseError < Bolt::Error
      attr_reader :issue_code

      def initialize(message, issue_code)
        super(message, kind, nil, issue_code)
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

    class EscalateError < BaseError
      def kind
        'puppetlabs.tasks/escalate-error'
      end
    end

    class FileError < BaseError
      def kind
        'puppetlabs.tasks/task_file_error'
      end
    end

    class EnvironmentVarError < BaseError
      def initialize(var, val)
        message = "Could not set environment variable '#{var}' to '#{val}'"
        super(message, 'ENVVAR_ERROR')
      end

      def kind
        'puppetlabs.tasks/environment-var-error'
      end
    end
  end
end
