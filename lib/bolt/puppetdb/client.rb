# frozen_string_literal: true

require 'json'
require 'logging'
require_relative '../../bolt/puppetdb/instance'

module Bolt
  module PuppetDB
    class Client
      # @param config [Hash] A map of default PuppetDB configuration.
      # @param instances [Hash] A map of configuration for named PuppetDB instances.
      # @param default [String] The name of PuppetDB instance to use as the default.
      # @param project [String] The path to the Bolt project.
      #
      def initialize(config:, instances: {}, default: nil, project: nil)
        @logger = Bolt::Logger.logger(self)

        @instances = instances.transform_values do |instance_config|
          Bolt::PuppetDB::Instance.new(config: instance_config, project: project)
        end

        @default_instance = if default
                              validate_instance(default)
                              @instances[default]
                            else
                              Bolt::PuppetDB::Instance.new(config: config, project: project, load_defaults: true)
                            end
      end

      # Checks whether a given named instance is configured, erroring if not.
      #
      # @param name [String] The name of the PuppetDB instance.
      #
      private def validate_instance(name)
        unless @instances[name]
          raise Bolt::PuppetDBError, "PuppetDB instance '#{name}' has not been configured, unable to connect"
        end
      end

      # Yields the PuppetDB instance to connect to.
      #
      # @param name [String] The name of the PuppetDB instance.
      # @yield [Bolt::PuppetDB::Instance]
      #
      private def with_instance(name = nil)
        yield instance(name)
      end

      # Selects the PuppetDB instance to connect to. If an instance is not specified,
      # the default instance is used.
      #
      # @param name [String] The name of the PuppetDB instance.
      # @return [Bolt::PuppetDB::Instance]
      #
      def instance(name = nil)
        if name
          validate_instance(name)
          @instances[name]
        else
          @default_instance
        end
      end

      # Queries certnames from the PuppetDB instance.
      #
      # @param query [String] The PDB query.
      # @param instance [String] The name of the PuppetDB instance.
      #
      def query_certnames(query, instance = nil)
        return [] unless query

        @logger.debug("Querying certnames")
        results = make_query(query, nil, instance)

        if results&.first && !results.first&.key?('certname')
          fields = results.first&.keys
          raise Bolt::PuppetDBError, "Query results did not contain a 'certname' field: got #{fields.join(', ')}"
        end

        results&.map { |result| result['certname'] }&.uniq
      end

      # Retrieve facts from PuppetDB for a list of nodes.
      #
      # @param certnames [Array] The list of certnames to retrieve facts for.
      # @param instance [String] The name of the PuppetDB instance.
      #
      def facts_for_node(certnames, instance = nil)
        return {} if certnames.empty? || certnames.nil?

        certnames.uniq!
        name_query = certnames.map { |c| ["=", "certname", c] }
        name_query.insert(0, "or")

        @logger.debug("Querying certnames")
        result = make_query(name_query, 'inventory', instance)

        result&.each_with_object({}) do |node, coll|
          coll[node['certname']] = node['facts']
        end
      end

      # Retrive fact values for a list of nodes.
      #
      # @param certnames [Array] The list of certnames to retrieve fact values for.
      # @param facts [Array] The list of facts to retrive.
      # @param instance [String] The name of the PuppetDB instance.
      #
      def fact_values(certnames = [], facts = [], instance = nil)
        return {} if certnames.empty? || facts.empty?

        certnames.uniq!
        name_query = certnames.map { |c| ["=", "certname", c] }
        name_query.insert(0, "or")

        facts_query = facts.map { |f| ["=", "path", f] }
        facts_query.insert(0, "or")

        query = ['and', name_query, facts_query]

        @logger.debug("Querying certnames")
        result = make_query(query, 'fact-contents', instance)
        result.map! { |h| h.delete_if { |k, _v| %w[environment name].include?(k) } }
        result.group_by { |c| c['certname'] }
      end

      # Sends a command to PuppetDB using the commands API.
      #
      # @param command [String] The command to invoke.
      # @param version [Integer] The version of the command to invoke.
      # @param payload [Hash] The payload to send with the command.
      # @param instance [String] The name of the PuppetDB instance.
      #
      def send_command(command, version, payload, instance = nil)
        with_instance(instance) do |pdb|
          pdb.send_command(command, version, payload)
        end
      end

      # Sends a query to PuppetDB.
      #
      # @param query [String] The query to send to PuppetDB.
      # @param path [String] The API path to append to the query URL.
      # @param instance [String] The name of the PuppetDB instance.
      #
      def make_query(query, path = nil, instance = nil)
        with_instance(instance) do |pdb|
          pdb.make_query(query, path)
        end
      end
    end
  end
end
