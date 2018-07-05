# frozen_string_literal: true

require 'json'
require 'uri'
require 'httpclient'

module Bolt
  module PuppetDB
    class Client
      def self.from_config(config)
        uri = if config['server_urls'].is_a? String
                config['server_urls']
              else
                config['server_urls'].first
              end
        uri = URI.parse(uri)
        uri.port ||= 8081

        cacert = File.expand_path(config['cacert'])
        token = config.token

        cert = config['cert']
        key = config['key']

        new(uri, cacert, token: token, cert: cert, key: key)
      end

      def initialize(uri, cacert, token: nil, cert: nil, key: nil)
        @uri = uri
        @cacert = cacert
        @token = token
        @cert = cert
        @key = key
      end

      def config
        {
          uri: @uri,
          cacert: @cacert,
          token: @token,
          cert: @cert,
          key: @key
        }
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
        url = "#{@uri}/pdb/query/v4"
        url += "/#{path}" if path

        begin
          response = http_client.post(url, body: body, header: headers)
        rescue StandardError => err
          raise Bolt::PuppetDBError, "Failed to query PuppetDB: #{err}"
        end
        if response.code != 200
          raise Bolt::PuppetDBError, "Failed to query PuppetDB: #{response.body}"
        end
        begin
          JSON.parse(response.body)
        rescue JSON::ParserError
          raise Bolt::PuppetDBError, "Unable to parse response as JSON: #{response.body}"
        end
      end

      def http_client
        return @http if @http
        @http = HTTPClient.new
        @http.ssl_config.set_client_cert_file(@cert, @key) if @cert
        @http.ssl_config.add_trust_ca(@cacert)

        @http
      end

      def headers
        headers = { 'Content-Type' => 'application/json' }
        headers['X-Authentication'] = @token if @token
        headers
      end
    end
  end
end
