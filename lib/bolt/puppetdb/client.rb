# frozen_string_literal: true

require 'json'
require 'logging'
require 'uri'

module Bolt
  module PuppetDB
    class Client
      attr_reader :config

      def initialize(config)
        @config = config
        @bad_urls = []
        @current_url = nil
        @logger = Logging.logger[self]
      end

      def ssl_cert
        @ssl_cert ||= File.read(@config.cert)
      end

      def ssl_key
        @ssl_key ||= File.read(@config.key)
      end

      def query_certnames(query)
        return [] unless query

        results = make_query(query)

        if results&.first && !results.first&.key?('certname')
          fields = results.first&.keys
          raise Bolt::PuppetDBError, "Query results did not contain a 'certname' field: got #{fields.join(', ')}"
        end
        results&.map { |result| result['certname'] }&.uniq
      end

      # This method expects an array of certnames to get facts for
      def facts_for_node(certnames)
        return {} if certnames.empty? || certnames.nil?

        certnames.uniq!
        name_query = certnames.map { |c| ["=", "certname", c] }
        name_query.insert(0, "or")
        result = make_query(name_query, 'inventory')

        result&.each_with_object({}) do |node, coll|
          coll[node['certname']] = node['facts']
        end
      end

      def fact_values(certnames = [], facts = [])
        return {} if certnames.empty? || facts.empty?

        certnames.uniq!
        name_query = certnames.map { |c| ["=", "certname", c] }
        name_query.insert(0, "or")

        facts_query = facts.map { |f| ["=", "path", f] }
        facts_query.insert(0, "or")

        query = ['and', name_query, facts_query]
        result = make_query(query, 'fact-contents')
        result.map! { |h| h.delete_if { |k, _v| %w[environment name].include?(k) } }
        result.group_by { |c| c['certname'] }
      end

      def make_query(query, path = nil)
        body = JSON.generate(query: query)
        url = "#{uri}/pdb/query/v4"
        url += "/#{path}" if path

        begin
          response = http_client.post(url, body, headers)
        rescue StandardError => e
          raise Bolt::PuppetDBFailoverError, "Failed to query PuppetDB: #{e}"
        end
        if response.code != '200'
          msg = "Failed to query PuppetDB: #{response.body}"
          if response.code == '400'
            raise Bolt::PuppetDBError, msg
          else
            raise Bolt::PuppetDBFailoverError, msg
          end
        end

        begin
          JSON.parse(response.body)
        rescue JSON::ParserError
          raise Bolt::PuppetDBError, "Unable to parse response as JSON: #{response.body}"
        end
      rescue Bolt::PuppetDBFailoverError => e
        @logger.error("Request to puppetdb at #{@current_url} failed with #{e}.")
        reject_url
        make_query(query, path)
      end

      def http_client
        @http_client ||= reset_http_client(uri)
      end

      def reset_http_client(uri)
        https = Net::HTTP.new(uri.host, uri.port)
        https.use_ssl = true
        https.ssl_version = :TLSv1_2
        https.ca_file = @config.cacert
        if @config.cert
          https.cert = OpenSSL::X509::Certificate.new(ssl_cert)
          https.key = OpenSSL::PKey::RSA.new(ssl_key)
          https.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end
        @http_client = https
      end

      def reject_url
        @bad_urls << @current_url if @current_url
        @current_url = nil
        reset_http_client(uri)
      end

      def uri
        @current_url ||= (@config.server_urls - @bad_urls).first
        unless @current_url
          msg = "Failed to connect to all PuppetDB server_urls: #{@config.server_urls.to_a.join(', ')}."
          raise Bolt::PuppetDBError, msg
        end

        uri = URI.parse(@current_url)
        uri.port ||= 8081
        uri
      end

      def headers
        headers = { 'Content-Type' => 'application/json' }
        headers['X-Authentication'] = @config.token if @config.token
        headers
      end
    end
  end
end
