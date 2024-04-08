# frozen_string_literal: true

require 'json'
require 'logging'
require_relative '../../bolt/puppetdb/config'

module Bolt
  module PuppetDB
    class Instance
      attr_reader :config

      def initialize(config:, project: nil, load_defaults: false)
        @config      = Bolt::PuppetDB::Config.new(config: config, project: project, load_defaults: load_defaults)
        @bad_urls    = []
        @current_url = nil
        @logger      = Bolt::Logger.logger(self)
      end

      def post_puppetdb(url, body)
        response = http_client.post(url, body: body, header: headers(@config.token))
        if response.status == 401 && @token_and_cert
          @logger.debug("Invalid token: #{response.body}, retrying with cert based auth")
          response = http_client.post(url, body: body, header: headers)
          if response.ok?
            @logger.debug("Puppetdb token is invalid, but certs are not. No longer including token.")
            @bad_token = true
          end
        end
        response
      end

      def make_query(query, path = nil)
        body = JSON.generate(query: query)
        url = "#{uri}/pdb/query/v4"
        url += "/#{path}" if path

        begin
          @logger.debug("Sending PuppetDB query to #{url}")
          response = post_puppetdb(url, body)
        rescue StandardError => e
          raise Bolt::PuppetDBFailoverError, "Failed to query PuppetDB: #{e}"
        end

        @logger.debug("Got response code #{response.code} from PuppetDB")
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
      rescue Bolt::PuppetDBFailoverError => e
        @logger.error("Request to puppetdb at #{@current_url} failed with #{e}.")
        reject_url
        make_query(query, path)
      end

      # Sends a command to PuppetDB using version 1 of the commands API.
      # https://puppet.com/docs/puppetdb/latest/api/command/v1/commands.html
      #
      # @param command [String] The command to invoke.
      # @param version [Integer] The version of the command to invoke.
      # @param payload [Hash] The payload to send with the command.
      # @return A UUID identifying the submitted command.
      #
      def send_command(command, version, payload)
        command = command.dup.force_encoding('utf-8')
        body    = JSON.generate(payload)

        # PDB requires the following query parameters to the POST request.
        # Error early if there's no certname, as PDB does not return a
        # message indicating it's required.
        unless payload['certname']
          raise Bolt::Error.new(
            "Payload must include 'certname', unable to invoke command.",
            'bolt/pdb-command'
          )
        end

        url = uri.tap do |u|
          u.path         = 'pdb/cmd/v1'
          u.query_values = { 'command'  => command,
                             'version'  => version,
                             'certname' => payload['certname'] }
        end

        # Send the command to PDB
        begin
          @logger.debug("Sending PuppetDB command '#{command}' to #{url}")
          response = post_puppetdb(url.to_s, body)
        rescue StandardError => e
          raise Bolt::PuppetDBFailoverError, "Failed to invoke PuppetDB command: #{e}"
        end

        @logger.debug("Got response code #{response.code} from PuppetDB")
        if response.code != 200
          raise Bolt::PuppetDBError, "Failed to invoke PuppetDB command: #{response.body}"
        end

        # Return the UUID string from the response body
        begin
          JSON.parse(response.body).fetch('uuid', nil)
        rescue JSON::ParserError
          raise Bolt::PuppetDBError, "Unable to parse response as JSON: #{response.body}"
        end
      rescue Bolt::PuppetDBFailoverError => e
        @logger.error("Request to puppetdb at #{@current_url} failed with #{e}.")
        reject_url
        send_command(command, version, payload)
      end

      def http_client
        return @http if @http
        # lazy-load expensive gem code
        require 'httpclient'
        @logger.trace("Creating HTTP Client")
        @http = HTTPClient.new
        @http.ssl_config.add_trust_ca(@config.cacert)
        @http.connect_timeout = @config.connect_timeout if @config.connect_timeout
        @http.receive_timeout = @config.read_timeout if @config.read_timeout
        # Determine if there are both token and cert auth methods defined
        @token_and_cert = false
        if @config.cert
          @http.ssl_config.set_client_cert_file(@config.cert, @config.key)
          @token_and_cert = !@config.token.nil?
        end
        @http
      end

      def reject_url
        @bad_urls << @current_url if @current_url
        @current_url = nil
      end

      def uri
        require 'addressable/uri'

        @current_url ||= (@config.server_urls - @bad_urls).first
        unless @current_url
          msg = "Failed to connect to all PuppetDB server_urls: #{@config.server_urls.to_a.join(', ')}."
          raise Bolt::PuppetDBError, msg
        end

        uri = Addressable::URI.parse(@current_url)
        uri.port ||= 8081
        uri
      end

      def headers(token = nil)
        headers = { 'Content-Type' => 'application/json' }
        headers['X-Authentication'] = token if token && !@bad_token
        headers
      end
    end
  end
end
