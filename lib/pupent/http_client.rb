# frozen_string_literal: true

require 'net/http'
require 'puppet/ssl'
require 'json'
require_relative '../bolt/error'

module PupEnt
  class HttpClient
    MISSING_CA_ERROR = <<-ERR

ERROR: Unable to read CA certificate

pupent requires a valid CA certificate from the PE primary in order to communicate
using TLS over https. You can download the CA certificate with:

bolt file download /etc/puppetlabs/puppet/ssl/certs/ca.pem [Local file location] --targets [PE Primary Hostname]

See "bolt file download --help" for more information on using that command
    ERR

    def initialize(pe_url, ca_cert)
      @logger = Bolt::Logger.logger(self)
      if pe_url.nil? || pe_url.empty?
        msg = "ERROR: URL of PE Primary missing or empty"
        @logger.error(msg)
        raise Bolt::Error.new(msg, 'bolt/http-error')
      end
      if ca_cert.nil? || ca_cert.empty?
        @logger.error(MISSING_CA_ERROR)
        raise Bolt::Error.new(MISSING_CA_ERROR, 'bolt/http-error')
      end
      @logger.debug("Read and parse CA")
      ca_certs = File.read(ca_cert).scan(/-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m).map do |cert|
        OpenSSL::X509::Certificate.new(cert)
      end

      @logger.debug("Create SSL context")
      ssl_prov = Puppet::SSL::SSLProvider.new
      @ssl_context = ssl_prov.create_root_context(
        cacerts: ca_certs,
        revocation: false
      )
      @client = Puppet.runtime[:http]
      @pe_url = pe_url
    rescue Errno::ENOENT
      @logger.error(MISSING_CA_ERROR)
      raise Bolt::Error.new(MISSING_CA_ERROR, 'bolt/http-error')
    end

    def pe_get(url_path, headers: {}, sensitive: false)
      handle_request(url_path, sensitive: sensitive) do |full_url|
        @client.get(
          full_url,
          headers: { 'Content-Type': 'application/json' }.merge(headers),
          options: { ssl_context: @ssl_context }
        )
      end
    end

    def pe_post(url_path, body, headers: {}, sensitive: false)
      handle_request(url_path, body: body, sensitive: sensitive) do |full_url, json_body|
        @client.post(
          full_url,
          json_body,
          headers: { 'Content-Type': 'application/json' }.merge(headers),
          options: { ssl_context: @ssl_context }
        )
      end
    end

    def pe_put(url_path, body, headers: {}, sensitive: false)
      handle_request(url_path, body: body, sensitive: sensitive) do |full_url, json_body|
        @client.put(
          full_url,
          json_body,
          headers: { 'Content-Type': 'application/json' }.merge(headers),
          options: { ssl_context: @ssl_context }
        )
      end
    end

    private

    # Handle URL creation, JSON encoding/decoding, and errors for http requests
    def handle_request(url_path, body: nil, sensitive: false)
      # Make sure the URL starts with the PE URL, otherwise assume the
      # path was provided without the hostname
      full_url = if url_path.include?(@pe_url)
                   URI(url_path)
                 else
                   URI(@pe_url + url_path)
                 end
      # Don't attempt to JSON.generate a nil body
      json_body = if body.nil?
                    nil
                  else
                    JSON.generate(body)
                  end

      http_response = if body.nil?
                        yield full_url
                      else
                        yield full_url, json_body
                      end

      # Throw and catch the response error. Throwing allows us to
      # capture if another part of the stack throws this error.
      # rubocop:disable Style/RaiseArgs
      unless http_response.success?
        raise Puppet::HTTP::ResponseError.new(http_response)
      end
      # rubocop:enable Style/RaiseArgs

      if http_response.body.nil? || http_response.body.empty?
        ["", http_response.code]
      else
        [JSON.parse(http_response.body), http_response.code]
      end
    rescue Puppet::HTTP::ResponseError => e
      msg = ""
      if sensitive
        msg = "PE API request returned HTTP code #{e.response.code}"
        @logger.error(msg)
        # Use trace to print the message in case the request contained something sensitive
        @logger.trace("Failure message: #{e.message}")
      else
        msg = "PE API request returned HTTP code #{e.response.code} with message\n#{e.message}"
        @logger.error(msg)
      end
      raise Bolt::Error.new(msg, 'bolt/http-error')
    rescue StandardError => e
      msg = ""
      if sensitive
        msg = "Exception #{e.class.name} thrown while attempting API request to PE"
        @logger.error(msg)
        # Use trace to print the message in case the request contained something sensitive
        @logger.trace("Exception message: #{e.message}")
      else
        msg = "Exception #{e.class.name} thrown while attempting API request to PE with message\n#{e.message}"
        @logger.error(msg)
      end
      raise Bolt::Error.new(msg, 'bolt/unexpected-error')
    end
  end
end
