# frozen_string_literal: true

module Bolt
  module Forge
    class Token
      def initialize
        @token = ENV['BOLT_FORGE_TOKEN']
      end

      def validate!
        #TODO: What bolt error should be raised here? bolt/forge/token? or something else?
        raise Bolt::Error.new("BOLT_FORGE_TOKEN is not set", 'bolt/get-resources') unless @token
        raise Bolt::Error.new("BOLT_FORGE_TOKEN is invalid", 'bolt/get-resources') unless valid_token?
      end

      def token
        @token
      end

      private

      def valid_token?
        # Implement token validation logic, e.g., regex or API call
        @token.match?(/\A[a-zA-Z0-9]+\z/)
      end
    end
  end
end
