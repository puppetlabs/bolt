# frozen_string_literal: true

require 'json'
require 'logging'
require 'uri'
require 'httpclient'

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

      def make_query(query, path = nil)
        body = JSON.generate(query: query)
        url = "#{uri}/pdb/query/v4"
        url += "/#{path}" if path

        begin
          response = http_client.post(url, body: body, header: headers)
        rescue SocketError, OpenSSL::SSL::SSLError, SystemCallError, Net::ProtocolError, IOError => err
          raise Bolt::PuppetDBFailoverError, "Failed to query PuppetDB: #{err}"
        rescue StandardError => err
          raise Bolt::PuppetDBError, "Failed to query PuppetDB: #{err}"
        end

        if response.code != 200
          msg = "Failed to query PuppetDB: #{response.body}"
          if response.code == 400
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
      rescue Bolt::PuppetDBFailoverError => err
        @logger.error("Request to puppetdb at #{@current_url} failed with #{err}.")
        reject_url
        make_query(query, path)
      end

      def http_client
        return @http if @http
        @http = HTTPClient.new
        @http.ssl_config.set_client_cert_file(@config.cert, @config.key) if @config.cert
        @http.ssl_config.add_trust_ca(@config.cacert)

        @http
      end

      def reject_url
        @bad_urls << @current_url if @current_url
        @current_url = nil
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
