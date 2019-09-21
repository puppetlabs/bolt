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

      TARGET_OPTS = %w[uri name config].freeze

      def initialize(pdb_client)
        @puppetdb_client = pdb_client
        @logger = Logging.logger[self]
      end

      def name
        'puppetdb'
      end

      def hooks
        ['inventory_targets']
      end

      def warn_missing_fact(certname, fact)
        @logger.warn("Could not find fact #{fact} for node #{certname}")
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

      def inventory_targets(opts)
        targets = @puppetdb_client.query_certnames(opts['query'])
        facts = []

        target_opts = opts.select { |k, _| TARGET_OPTS.include?(k) }
        Bolt::Util.walk_vals(target_opts) do |value|
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
          target = resolve_facts(target_opts, certname, target_data) || {}
          target['uri'] = certname unless target['uri'] || target['name']

          target
        end
      end

      def resolve_facts(config, certname, target_data)
        Bolt::Util.walk_vals(config) do |value|
          if value.is_a?(String)
            data = target_data&.detect { |d| d['path'] == fact_path(value) }
            warn_missing_fact(certname, value) if data.nil?
            # If there's no fact data this will be nil
            data&.fetch('value', nil)
          elsif value.is_a?(Array) || value.is_a?(Hash)
            value
          else
            raise FactLookupError.new(value, "fact lookups must be a string")
          end
        end
      end
    end
  end
end
