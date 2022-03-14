# frozen_string_literal: true

module Bolt
  class Plugin
    class Puppetdb
      class FactLookupError < Bolt::Error
        def initialize(fact, err = nil)
          m = String.new("Fact lookup '#{fact}' contains an invalid factname")
          m << ": #{err}" unless err.nil?
          super(m, 'bolt.plugin/fact-lookup-error')
        end
      end

      TEMPLATE_OPTS = %w[alias config facts features name uri vars].freeze
      PLUGIN_OPTS = %w[_plugin _cache query target_mapping].freeze

      attr_reader :puppetdb_client

      def initialize(config:, context:)
        pdb_config = Bolt::PuppetDB::Config.load_config(config, context.boltdir)
        @puppetdb_client = Bolt::PuppetDB::Client.new(pdb_config)
        @logger = Bolt::Logger.logger(self)
      end

      def name
        'puppetdb'
      end

      def hooks
        hook_descriptions.keys
      end

      def hook_descriptions
        {
          resolve_reference: 'Query PuppetDB for a group of targets.'
        }
      end

      def warn_missing_fact(certname, fact)
        Bolt::Logger.warn("puppetdb_missing_fact", "Could not find fact #{fact} for node #{certname}")
      end

      def fact_path(raw_fact)
        fact_path = raw_fact.split(".")
        if fact_path[0] == 'facts'
          fact_path.drop(1)
        elsif fact_path == ['certname']
          fact_path
        else
          raise FactLookupError.new(raw_fact, "fact lookups must start with 'facts.'")
        end
      end

      def resolve_reference(opts)
        targets = @puppetdb_client.query_certnames(opts['query'])
        facts = []

        template = opts.delete('target_mapping') || {}

        keys = Set.new(TEMPLATE_OPTS) & opts.keys
        unless keys.empty?
          raise Bolt::ValidationError, "PuppetDB plugin expects keys #{keys.to_a} to be set under 'target_mapping'"
        end

        keys = Set.new(opts.keys) - PLUGIN_OPTS
        unless keys.empty?
          raise Bolt::ValidationError, "Unknown keys in PuppetDB plugin: #{keys.to_a}"
        end

        Bolt::Util.walk_vals(template) do |value|
          # This is done in parts instead of in place so that we only need to
          # make one puppetDB query
          if value.is_a?(String)
            facts << fact_path(value)
          end
          value
        end

        facts.uniq!
        # Returns {'mycertname' => [{'path' => ['nested', 'fact'], 'value' => val'}], ... }
        fact_values = @puppetdb_client.fact_values(targets, facts)

        targets.map do |certname|
          target_data = fact_values[certname]
          target = resolve_facts(template, certname, target_data) || {}
          target['uri'] = certname unless target['uri'] || target['name']

          target
        end
      end

      def resolve_facts(config, certname, target_data)
        Bolt::Util.walk_vals(config) do |value|
          case value
          when String
            if value == 'certname'
              certname
            else
              data = target_data&.detect { |d| d['path'] == fact_path(value) }
              warn_missing_fact(certname, value) if data.nil?
              # If there's no fact data this will be nil
              data&.fetch('value', nil)
            end
          when Array, Hash
            value
          else
            raise FactLookupError.new(value, "fact lookups must be a string")
          end
        end
      end
    end
  end
end
