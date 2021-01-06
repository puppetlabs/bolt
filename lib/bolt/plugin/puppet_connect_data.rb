# frozen_string_literal: true

module Bolt
  class Plugin
    class PuppetConnectData
      def initialize(context:, **_opts)
        puppet_connect_data_yaml_path = File.join(context.boltdir, 'puppet_connect_data.yaml')
        @data = Bolt::Util.read_optional_yaml_hash(
          puppet_connect_data_yaml_path,
          'puppet_connect_data.yaml'
        )
      end

      def name
        'puppet_connect_data'
      end

      def hooks
        %i[resolve_reference validate_resolve_reference]
      end

      def resolve_reference(opts)
        key = opts['key']
        @data[key]
      end

      def validate_resolve_reference(opts)
        unless opts['key']
          raise Bolt::ValidationError,
                "puppet_connect_data plugin requires that 'key' be specified"
        end
      end
    end
  end
end
