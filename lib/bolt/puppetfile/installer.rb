# frozen_string_literal: true

require 'spec_helper'
require 'bolt/forge/token'

module Bolt
  class Puppetfile
    class Installer
      def initialize
        @forge_token = Bolt::Forge::Token.new
        @forge_token.validate!
      end

      def install
        # Use @forge_token.token in HTTP requests
        headers = { 'Authorization' => "Bearer #{@forge_token.token}" }
        # Existing installation logic
      end
    end
  end
end
