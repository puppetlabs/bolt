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

      def query_certnames(query)
        return [] unless query

        body = JSON.generate(query: query)

        response = http_client.post("#{@uri}/pdb/query/v4", body: body, header: headers)
        if response.code != 200
          raise Bolt::PuppetDBError, "Failed to query PuppetDB: #{response.body}"
        else
          results = JSON.parse(response.body)
          if results.first && !results.first.key?('certname')
            fields = results.first.keys
            raise Bolt::PuppetDBError, "Query results did not contain a 'certname' field: got #{fields.join(', ')}"
          end
          results.map { |result| result['certname'] }.uniq
        end
      end

      def http_client
        return @http if @http
        @http = HTTPClient.new
        @http.ssl_config.set_client_cert_file(@cert, @key)
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
