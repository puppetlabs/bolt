# frozen_string_literal: true

require 'json'

module Puma
  module Stats
    class App
      def initialize(launcher)
        @launcher = launcher
        @auth_token = launcher.options[:stats_token]
      end

      def call(env)
        return rack_response(403, 'Invalid stats auth token', 'text/plain') unless authenticate(env)

        case env['PATH_INFO']
        when %r{/puma-stats-gc$}
          rack_response(200, GC.stat.to_json)

        when %r{/puma-stats$}
          rack_response(200, @launcher.stats)

        else
          rack_response 404, 'Unsupported request', 'text/plain'
        end
      end

      private

      def authenticate(env)
        return true unless @auth_token

        env['QUERY_STRING'].to_s.split(/&;/).include?("token=#{@auth_token}")
      end

      def rack_response(status, body, content_type = 'application/json')
        headers = {
          'Content-Type' => content_type,
          'Content-Length' => body.bytesize.to_s
        }
        [status, headers, [body]]
      end
    end
  end
end
