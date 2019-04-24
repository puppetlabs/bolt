# frozen_string_literal: true

module Bolt
  class Plugin
    class Puppetdb
      def initialize(pdb_client)
        @puppetdb_client = pdb_client
      end

      def name
        'puppetdb'
      end

      def hooks
        ['lookup_targets']
      end

      def lookup_targets(opts)
        nodes = @puppetdb_client.query_certnames(opts['query'])
        nodes.map { |certname| { 'uri' => certname } }
      end
    end
  end
end
