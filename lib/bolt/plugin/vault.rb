# frozen_string_literal: true

module Bolt
  class Plugin
    class Vault
      class VaultHTTPError < Bolt::Error
        def initialize(response)
          err = JSON.parse(response.body)['errors']
          m = String.new("#{response.code} \"#{response.msg}\"")
          m << ": #{err.join(';')}" unless err.nil?
          super(m, 'bolt.plugin/vault-http-error')
        end
      end

      attr_reader :config

      # All requests for secrets must have a token in the request header
      TOKEN_HEADER = "X-Vault-Token"

      # Default header for all requests, including auth methods
      DEFAULT_HEADER = {
        "Content-Type" => "application/json",
        "Accept" => "application/json"
      }.freeze

      # Make sure no unexpected keys are in the config
      def validate_config(config)
        known_keys = %w[server_url auth cacert]

        config.each do |key, _v|
          next if known_keys.include?(key)
          raise Bolt::ValidationError, "Unexpected key in Vault plugin config: #{key}"
        end
      end

      # Make sure no unexpected keys are in the inventory config and
      # that required keys are present
      def validate_options(opts)
        known_keys = %w[_plugin server_url auth path field version cacert]
        required_keys = %w[path]

        opts.each do |key, _v|
          next if known_keys.include?(key)
          raise Bolt::ValidationError, "Unexpected key in inventory config: #{key}"
        end

        required_keys.each do |key|
          next if opts[key]
          raise Bolt::ValidationError, "Expected key in inventory config: #{key}"
        end
      end

      def name
        'vault'
      end

      def hooks
        [:resolve_reference]
      end

      def initialize(config:, **_opts)
        validate_config(config)
        @config = config
        @logger = Logging.logger[self]
      end

      def resolve_reference(opts)
        validate_options(opts)

        header = {
          TOKEN_HEADER => token(opts)
        }

        response = request(:Get, uri(opts), opts, nil, header)

        parse_response(response, opts)
      end

      # Request uri - built up from Vault server url and secrets path
      def uri(opts, path = nil)
        url = opts['server_url'] || config['server_url'] || ENV['VAULT_ADDR']

        # Handle the different versions of the API
        if opts['version'] == 2
          mount, store = opts['path'].split('/', 2)
          opts['path'] = [mount, 'data', store].join('/')
        end

        path ||= opts['path']

        URI.parse(File.join(url, "v1", path))
      end

      # Configure the http/s client
      def client(uri, opts)
        client = Net::HTTP.new(uri.host, uri.port)

        if uri.scheme == 'https'
          cacert = opts['cacert'] || config['cacert'] || ENV['VAULT_CACERT']

          unless cacert
            raise Bolt::ValidationError, "Expected cacert to be set when using https"
          end

          client.use_ssl = true
          client.ssl_version = :TLSv1_2
          client.ca_file = cacert
          client.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end

        client
      end

      # Auth token to vault server
      def token(opts)
        if (auth = opts['auth'] || config['auth'])
          request_token(auth, opts)
        else
          ENV['VAULT_TOKEN']
        end
      end

      def request(verb, uri, opts, data, header = {})
        # Add on any header options
        header = DEFAULT_HEADER.merge(header)

        # Create the HTTP request
        client = client(uri, opts)
        request = Net::HTTP.const_get(verb).new(uri.request_uri, header)

        # Attach any data
        request.body = data if data

        # Send the request
        begin
          response = client.request(request)
        rescue StandardError => e
          raise Bolt::Error.new(
            "Failed to connect to #{uri}: #{e.message}",
            'CONNECT_ERROR'
          )
        end

        case response
        when Net::HTTPOK
          JSON.parse(response.body)
        else
          raise VaultHTTPError, response
        end
      end

      def parse_response(response, opts)
        data = case opts['version']
               when 2
                 response['data']['data']
               else
                 response['data']
               end

        if opts['field']
          unless data[opts['field']]
            raise Bolt::ValidationError, "Unknown secrets field: #{opts['field']}"
          end
          data[opts['field']]
        else
          data
        end
      end

      # Request a token from Vault using one of the auth methods
      def request_token(auth, opts)
        case auth['method']
        when 'token'
          auth_token(auth)
        when 'userpass'
          auth_userpass(auth, opts)
        else
          raise Bolt::ValidationError, "Unknown auth method: #{auth['method']}"
        end
      end

      def validate_auth(auth, required_keys)
        required_keys.each do |key|
          next if auth[key]
          raise Bolt::ValidationError, "Expected key in #{auth['method']} auth method: #{key}"
        end
      end

      # Authenticate with Vault using the 'Token' auth method
      def auth_token(auth)
        validate_auth(auth, %w[token])
        auth['token']
      end

      # Authenticate with Vault using the 'Userpass' auth method
      def auth_userpass(auth, opts)
        validate_auth(auth, %w[user pass])
        path = "auth/userpass/login/#{auth['user']}"
        uri = uri(opts, path)
        data = { "password" => auth['pass'] }.to_json

        request(:Post, uri, opts, data)['auth']['client_token']
      end
    end
  end
end
