# frozen_string_literal: true

module BoltServer
  class Plugin
    class PuppetConnectData
      def initialize(data, **_opts)
        @data = data
      end

      def name
        'puppet_connect_data'
      end

      def hooks
        %i[resolve_reference validate_resolve_reference]
      end

      def resolve_reference(opts)
        key = opts['key']

        @data.dig(key, 'value')
      end

      def validate_resolve_reference(opts)
        unless opts['key']
          raise Bolt::ValidationError,
                "puppet_connect_data plugin requires that 'key' be specified"
        end

        unless @data.key?(opts['key'])
          raise Bolt::ValidationError,
                "puppet_connect_data plugin tried to lookup key '#{opts['key']}' but no value was found"
        end
      end
    end
  end
end
